// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./interfaces/IUniversalRouter.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IRouterImmutables.sol";
import "./libraries/Commands.sol";

/**
 * @title VelodromeSwap
 * @dev Contract for swapping tokens using Velodrome Universal Router
 * NOTE: Before using, verify that a pool exists between your tokens!
 */
contract VelodromeSwapCopy {
    IUniversalRouter public constant UNIVERSAL_ROUTER =
        IUniversalRouter(0x01D40099fCD87C018969B0e8D4aB1633Fb34763C);

    address public constant USDT = 0x05D032ac25d322df992303dCa074EE7392C117b9;
    address public constant USDTO = 0x43F2376D5D03553aE72F4A8093bbe9de4336EB08;

    // Events
    event SwapExecuted(
        address indexed user,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut
    );

    /**
     * @dev Swap USDT for USDTO using Velodrome Universal Router
     * @param amountIn Amount of USDT to swap
     * @param amountOutMin Minimum amount of USDTO to receive (slippage protection)
     * @param to Address to receive the USDTO tokens
     * @param deadline Transaction deadline timestamp
     * @return amountOut Amount of USDTO received
     */
    function swapUSDTToUSDTO(
        uint256 amountIn,
        uint256 amountOutMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountOut) {
        require(amountIn > 0, "Amount must be greater than 0");
        require(to != address(0), "Invalid recipient address");

        // Transfer USDT from user to this contract
        IERC20(USDT).transferFrom(msg.sender, address(this), amountIn);

        // Approve Universal Router to spend USDT
        IERC20(USDT).approve(address(UNIVERSAL_ROUTER), amountIn);

        // Build path for V2 swap with stable pool flag
        // Velodrome V2 path format: [tokenIn, tokenOut] with separate stable flag array
        address[] memory path = new address[](2);
        path[0] = USDT;
        path[1] = USDTO;

        // For stablecoin swaps, use stable pool (true)
        bool[] memory stable = new bool[](1);
        stable[0] = true; // Use stable pool for USDT <-> USDTO

        // Encode V2 swap input for UniversalRouter
        // Correct format: (recipient, amountIn, amountOutMin, path, stable[], payerIsUser)
        bytes memory input = abi.encode(
            to, // recipient
            amountIn, // amountIn
            amountOutMin, // amountOutMin
            path, // path
            stable, // stable pool flags
            false // payerIsUser = false (tokens already in contract)
        );

        // Build commands and inputs
        bytes memory commands = abi.encodePacked(
            bytes1(uint8(Commands.V2_SWAP_EXACT_IN))
        );
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = input;

        // Record balance before swap
        uint256 balanceBefore = IERC20(USDTO).balanceOf(to);

        // Execute swap
        UNIVERSAL_ROUTER.execute(commands, inputs, deadline);

        // Calculate amount received
        amountOut = IERC20(USDTO).balanceOf(to) - balanceBefore;

        emit SwapExecuted(msg.sender, USDT, USDTO, amountIn, amountOut);

        return amountOut;
    }

    /**
     * @dev Swap USDTO for USDT using Velodrome Universal Router
     * @param amountIn Amount of USDTO to swap
     * @param amountOutMin Minimum amount of USDT to receive (slippage protection)
     * @param to Address to receive the USDT tokens
     * @param deadline Transaction deadline timestamp
     * @return amountOut Amount of USDT received
     */
    function swapUSDTOToUSDT(
        uint256 amountIn,
        uint256 amountOutMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountOut) {
        require(amountIn > 0, "Amount must be greater than 0");
        require(to != address(0), "Invalid recipient address");

        // Transfer USDTO from user to this contract
        IERC20(USDTO).transferFrom(msg.sender, address(this), amountIn);

        // Approve Universal Router to spend USDTO
        IERC20(USDTO).approve(address(UNIVERSAL_ROUTER), amountIn);

        // Build path for V2 swap with stable pool flag
        address[] memory path = new address[](2);
        path[0] = USDTO;
        path[1] = USDT;

        // For stablecoin swaps, use stable pool (true)
        bool[] memory stable = new bool[](1);
        stable[0] = true; // Use stable pool for USDTO <-> USDT

        // Encode V2 swap input for UniversalRouter
        bytes memory input = abi.encode(
            to, // recipient
            amountIn, // amountIn
            amountOutMin, // amountOutMin
            path, // path
            stable, // stable pool flags
            false // payerIsUser = false
        );

        // Build commands and inputs
        bytes memory commands = abi.encodePacked(
            bytes1(uint8(Commands.V2_SWAP_EXACT_IN))
        );
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = input;

        // Record balance before swap
        uint256 balanceBefore = IERC20(USDT).balanceOf(to);

        // Execute swap
        UNIVERSAL_ROUTER.execute(commands, inputs, deadline);

        // Calculate amount received
        amountOut = IERC20(USDT).balanceOf(to) - balanceBefore;

        emit SwapExecuted(msg.sender, USDTO, USDT, amountIn, amountOut);

        return amountOut;
    }

    /**
     * @dev Emergency function to recover any tokens sent to this contract
     * @param token Token address to recover
     * @param to Address to send recovered tokens
     */
    function recoverToken(address token, address to) external {
        require(to != address(0), "Invalid recipient address");
        uint256 balance = IERC20(token).balanceOf(address(this));
        if (balance > 0) {
            IERC20(token).transfer(to, balance);
        }
    }
}
