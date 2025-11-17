// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../contracts/swap.sol";
import "../contracts/interfaces/IERC20.sol";
import "../contracts/interfaces/IUniversalRouter.sol";

contract SwapContractTest is Test {
    SwapContract public swapContract;

    address public constant UNIVERSAL_ROUTER =
        0x01D40099fCD87C018969B0e8D4aB1633Fb34763C;
    address public constant USDT = 0x05D032ac25d322df992303dCa074EE7392C117b9;
    address public constant USDTO = 0x43F2376D5D03553aE72F4A8093bbe9de4336EB08;

    address public user = address(0x1234);
    address public recipient = address(0x5678);

    uint256 public constant AMOUNT_IN = 1000 * 10 ** 6;
    uint256 public constant SLIPPAGE_BPS = 50;
    uint24 public constant POOL_FEE = 500;
    uint256 public deadline;

    IERC20 public usdtToken;
    IERC20 public usdtoToken;

    function setUp() public {
        vm.createFork(vm.rpcUrl("lisk"));

        usdtToken = IERC20(USDT);
        usdtoToken = IERC20(USDTO);

        swapContract = new SwapContract(UNIVERSAL_ROUTER, USDT, USDTO);

        deadline = block.timestamp + 3600;

        vm.label(UNIVERSAL_ROUTER, "UniversalRouter");
        vm.label(USDT, "USDT");
        vm.label(USDTO, "USDTO");
        vm.label(user, "User");
        vm.label(recipient, "Recipient");
        vm.label(address(swapContract), "SwapContract");
    }

    function test_Constructor() public view {
        assertEq(address(swapContract.UNIVERSAL_ROUTER()), UNIVERSAL_ROUTER);
        assertEq(swapContract.USDT(), USDT);
        assertEq(swapContract.USDTO(), USDTO);
    }

    function test_Constructor_InvalidRouter() public {
        vm.expectRevert("Invalid router address");
        new SwapContract(address(0), USDT, USDTO);
    }

    function test_Constructor_InvalidUSDT() public {
        vm.expectRevert("Invalid USDT address");
        new SwapContract(UNIVERSAL_ROUTER, address(0), USDTO);
    }

    function test_Constructor_InvalidUSDTO() public {
        vm.expectRevert("Invalid USDTO address");
        new SwapContract(UNIVERSAL_ROUTER, USDT, address(0));
    }

    function test_SwapUSDTToUSDTO() public {
        address userWithBalance = findUserWithBalance(USDT, AMOUNT_IN);

        if (userWithBalance == address(0)) {
            console.log("No user found with sufficient USDT balance");
            console.log(
                "Skipping test - need a user with at least",
                AMOUNT_IN,
                "USDT"
            );
            return;
        }

        console.log("Found user with USDT balance:", userWithBalance);

        vm.startPrank(userWithBalance);

        uint256 usdtBalanceBefore = usdtToken.balanceOf(userWithBalance);
        uint256 usdtoBalanceBefore = usdtoToken.balanceOf(recipient);

        uint256 amountOutMin = calculateMinAmountOut(AMOUNT_IN, SLIPPAGE_BPS);

        usdtToken.approve(address(swapContract), AMOUNT_IN);

        uint256 amountOut = swapContract.swapUSDTToUSDTO(
            AMOUNT_IN,
            amountOutMin,
            recipient,
            deadline,
            POOL_FEE
        );

        uint256 usdtBalanceAfter = usdtToken.balanceOf(userWithBalance);
        uint256 usdtoBalanceAfter = usdtoToken.balanceOf(recipient);

        assertEq(
            usdtBalanceBefore - usdtBalanceAfter,
            AMOUNT_IN,
            "USDT should be deducted"
        );
        assertGt(
            usdtoBalanceAfter,
            usdtoBalanceBefore,
            "USDTO balance should increase"
        );
        assertGe(amountOut, amountOutMin, "Amount out should meet minimum");

        vm.stopPrank();
    }

    function test_SwapUSDTOToUSDT() public {
        address userWithBalance = findUserWithBalance(USDTO, AMOUNT_IN);

        if (userWithBalance == address(0)) {
            console.log("No user found with sufficient USDTO balance");
            console.log(
                "Skipping test - need a user with at least",
                AMOUNT_IN,
                "USDTO"
            );
            return;
        }

        console.log("Found user with USDTO balance:", userWithBalance);

        vm.startPrank(userWithBalance);

        uint256 usdtoBalanceBefore = usdtoToken.balanceOf(userWithBalance);
        uint256 usdtBalanceBefore = usdtToken.balanceOf(recipient);

        uint256 amountOutMin = calculateMinAmountOut(AMOUNT_IN, SLIPPAGE_BPS);

        usdtoToken.approve(address(swapContract), AMOUNT_IN);

        uint256 amountOut = swapContract.swapUSDTOToUSDT(
            AMOUNT_IN,
            amountOutMin,
            recipient,
            deadline,
            POOL_FEE
        );

        uint256 usdtoBalanceAfter = usdtoToken.balanceOf(userWithBalance);
        uint256 usdtBalanceAfter = usdtToken.balanceOf(recipient);

        assertEq(
            usdtoBalanceBefore - usdtoBalanceAfter,
            AMOUNT_IN,
            "USDTO should be deducted"
        );
        assertGt(
            usdtBalanceAfter,
            usdtBalanceBefore,
            "USDT balance should increase"
        );
        assertGe(amountOut, amountOutMin, "Amount out should meet minimum");

        vm.stopPrank();
    }

    function test_SwapUSDTToUSDTO_InvalidAmount() public {
        vm.startPrank(user);

        vm.expectRevert("Amount must be greater than 0");
        swapContract.swapUSDTToUSDTO(0, 0, recipient, deadline, POOL_FEE);

        vm.stopPrank();
    }

    function test_SwapUSDTToUSDTO_InvalidRecipient() public {
        vm.startPrank(user);

        vm.expectRevert("Invalid recipient address");
        swapContract.swapUSDTToUSDTO(
            AMOUNT_IN,
            0,
            address(0),
            deadline,
            POOL_FEE
        );

        vm.stopPrank();
    }

    function test_SwapUSDTToUSDTO_DeadlinePassed() public {
        vm.startPrank(user);

        uint256 pastDeadline = block.timestamp - 1;

        vm.expectRevert("Deadline has passed");
        swapContract.swapUSDTToUSDTO(
            AMOUNT_IN,
            0,
            recipient,
            pastDeadline,
            POOL_FEE
        );

        vm.stopPrank();
    }

    function test_SwapUSDTToUSDTO_InsufficientOutput() public {
        address userWithBalance = findUserWithBalance(USDT, AMOUNT_IN);

        if (userWithBalance == address(0)) {
            console.log("No user found with sufficient USDT balance");
            return;
        }

        vm.startPrank(userWithBalance);

        uint256 unreasonablyHighMin = (AMOUNT_IN * 99) / 100;

        usdtToken.approve(address(swapContract), AMOUNT_IN);

        vm.expectRevert("Insufficient output amount");
        swapContract.swapUSDTToUSDTO(
            AMOUNT_IN,
            unreasonablyHighMin,
            recipient,
            deadline,
            POOL_FEE
        );

        vm.stopPrank();
    }

    function test_GenericSwap() public {
        address userWithBalance = findUserWithBalance(USDT, AMOUNT_IN);

        if (userWithBalance == address(0)) {
            console.log("No user found with sufficient USDT balance");
            return;
        }

        vm.startPrank(userWithBalance);

        uint256 usdtBalanceBefore = usdtToken.balanceOf(userWithBalance);
        uint256 usdtoBalanceBefore = usdtoToken.balanceOf(recipient);

        uint256 amountOutMin = calculateMinAmountOut(AMOUNT_IN, SLIPPAGE_BPS);

        usdtToken.approve(address(swapContract), AMOUNT_IN);

        uint256 amountOut = swapContract.swapV3(
            USDT,
            USDTO,
            AMOUNT_IN,
            amountOutMin,
            recipient,
            deadline,
            POOL_FEE
        );

        uint256 usdtBalanceAfter = usdtToken.balanceOf(userWithBalance);
        uint256 usdtoBalanceAfter = usdtoToken.balanceOf(recipient);

        assertEq(
            usdtBalanceBefore - usdtBalanceAfter,
            AMOUNT_IN,
            "USDT should be deducted"
        );
        assertGt(
            usdtoBalanceAfter,
            usdtoBalanceBefore,
            "USDTO balance should increase"
        );
        assertGe(amountOut, amountOutMin, "Amount out should meet minimum");

        vm.stopPrank();
    }

    function test_RecoverToken() public {
        address userWithBalance = findUserWithBalance(USDT, AMOUNT_IN);

        if (userWithBalance == address(0)) {
            console.log("No user found with sufficient USDT balance");
            return;
        }

        vm.startPrank(userWithBalance);

        uint256 recoveryAmount = 100 * 10 ** 6;
        usdtToken.transfer(address(swapContract), recoveryAmount);

        vm.stopPrank();

        uint256 balanceBefore = usdtToken.balanceOf(recipient);
        swapContract.recoverToken(USDT, recipient);
        uint256 balanceAfter = usdtToken.balanceOf(recipient);

        assertEq(
            balanceAfter - balanceBefore,
            recoveryAmount,
            "Recovered amount should match"
        );
    }

    function test_RecoverToken_InvalidRecipient() public {
        vm.expectRevert("Invalid recipient address");
        swapContract.recoverToken(USDT, address(0));
    }

    function test_RecoverToken_NoTokens() public {
        uint256 balance = usdtToken.balanceOf(address(swapContract));
        if (balance == 0) {
            vm.expectRevert("No tokens to recover");
            swapContract.recoverToken(USDT, recipient);
        }
    }

    function test_ActualSwapExecution() public {
        deal(USDT, user, AMOUNT_IN * 2, true);

        vm.startPrank(user);

        uint256 usdtBalanceBefore = usdtToken.balanceOf(user);
        uint256 usdtoBalanceBefore = usdtoToken.balanceOf(recipient);

        console.log("USDT balance before:", usdtBalanceBefore);
        console.log("USDTO balance before:", usdtoBalanceBefore);

        uint256 amountOutMin = calculateMinAmountOut(AMOUNT_IN, 100);

        usdtToken.approve(address(swapContract), AMOUNT_IN);

        uint256 amountOut = swapContract.swapUSDTToUSDTO(
            AMOUNT_IN,
            amountOutMin,
            recipient,
            deadline,
            POOL_FEE
        );

        uint256 usdtBalanceAfter = usdtToken.balanceOf(user);
        uint256 usdtoBalanceAfter = usdtoToken.balanceOf(recipient);

        console.log("USDT balance after:", usdtBalanceAfter);
        console.log("USDTO balance after:", usdtoBalanceAfter);
        console.log("Amount out received:", amountOut);

        assertEq(
            usdtBalanceBefore - usdtBalanceAfter,
            AMOUNT_IN,
            "USDT should be deducted from user"
        );
        assertGt(
            usdtoBalanceAfter,
            usdtoBalanceBefore,
            "USDTO balance should increase for recipient"
        );
        assertGe(
            amountOut,
            amountOutMin,
            "Amount out should meet minimum requirement"
        );
        assertEq(
            usdtoBalanceAfter - usdtoBalanceBefore,
            amountOut,
            "USDTO received should match amountOut"
        );

        vm.stopPrank();
    }

    function findUserWithBalance(
        address token,
        uint256 minBalance
    ) internal view returns (address) {
        address[] memory candidates = new address[](10);
        candidates[0] = 0x0000000000000000000000000000000000000001;
        candidates[1] = 0x0000000000000000000000000000000000000002;
        candidates[2] = 0x1111111111111111111111111111111111111111;
        candidates[3] = 0x2222222222222222222222222222222222222222;
        candidates[4] = 0x3333333333333333333333333333333333333333;
        candidates[5] = 0x4444444444444444444444444444444444444444;
        candidates[6] = 0x5555555555555555555555555555555555555555;
        candidates[7] = 0x6666666666666666666666666666666666666666;
        candidates[8] = 0x7777777777777777777777777777777777777777;
        candidates[9] = 0x8888888888888888888888888888888888888888;

        if (IERC20(token).balanceOf(UNIVERSAL_ROUTER) >= minBalance) {
            return UNIVERSAL_ROUTER;
        }

        for (uint256 i = 0; i < candidates.length; i++) {
            if (IERC20(token).balanceOf(candidates[i]) >= minBalance) {
                return candidates[i];
            }
        }

        return address(0);
    }

    function calculateMinAmountOut(
        uint256 amountIn,
        uint256 slippageBps
    ) internal pure returns (uint256) {
        uint256 slippageAmount = (amountIn * slippageBps) / 10000;
        return amountIn - slippageAmount;
    }
}
