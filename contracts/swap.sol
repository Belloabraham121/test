// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./interfaces/IUniversalRouter.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IRouterImmutables.sol";
import "./libraries/Commands.sol";

/**
 * @title SwapContract
 * @dev Contract for swapping tokens using Universal Router
 * NOTE: Before using, verify that a pool exists between your tokens!
 */
contract SwapContract {
    IUniversalRouter public immutable UNIVERSAL_ROUTER;

    // Token addresses
    address public immutable USDT;
    address public immutable USDTO;

    // Events
    event SwapExecuted(
        address indexed user,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut
    );

    constructor(address _universalRouter, address _usdt, address _usdto) {
        require(_universalRouter != address(0), "Invalid router address");
        require(_usdt != address(0), "Invalid USDT address");
        require(_usdto != address(0), "Invalid USDTO address");

        UNIVERSAL_ROUTER = IUniversalRouter(_universalRouter);
        USDT = _usdt;
        USDTO = _usdto;
    }

    /**
     * @dev Swap USDT for USDTO using Universal Router (V3 concentrated liquidity pool)
     * @param amountIn Amount of USDT to swap
     * @param amountOutMin Minimum amount of USDTO to receive (slippage protection)
     * @param to Address to receive the USDTO tokens
     * @param deadline Transaction deadline timestamp
     * @param fee Fee tier for the pool (e.g., 100 for 0.01%, 500 for 0.05%, 3000 for 0.3%)
     * @return amountOut Amount of USDTO received
     */
    function swapUSDTToUSDTO(
        uint256 amountIn,
        uint256 amountOutMin,
        address to,
        uint256 deadline,
        uint24 fee
    ) external returns (uint256 amountOut) {
        require(amountIn > 0, "Amount must be greater than 0");
        require(to != address(0), "Invalid recipient address");
        require(deadline >= block.timestamp, "Deadline has passed");

        // Transfer USDT from user to this contract
        IERC20(USDT).transferFrom(msg.sender, address(this), amountIn);

        // Approve Universal Router to spend USDT
        IERC20(USDT).approve(address(UNIVERSAL_ROUTER), amountIn);

        // Build V3 path: tokenIn (20 bytes) | fee (3 bytes) | tokenOut (20 bytes)
        bytes memory path = abi.encodePacked(USDT, fee, USDTO);

        // Encode V3 swap input for UniversalRouter
        // Format: (recipient, amountIn, amountOutMinimum, path, payer, isUni)
        bytes memory input = abi.encode(
            to, // recipient
            amountIn, // amountIn
            amountOutMin, // amountOutMinimum
            path, // path as bytes
            address(this), // payer (tokens are in this contract)
            false // isUni = false (Velodrome pool, not Uniswap)
        );

        // Build commands and inputs
        bytes memory commands = abi.encodePacked(
            bytes1(uint8(Commands.V3_SWAP_EXACT_IN))
        );
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = input;

        // Record balance before swap
        uint256 balanceBefore = IERC20(USDTO).balanceOf(to);

        // Execute swap
        UNIVERSAL_ROUTER.execute(commands, inputs, deadline);

        // Calculate amount received
        amountOut = IERC20(USDTO).balanceOf(to) - balanceBefore;

        require(amountOut >= amountOutMin, "Insufficient output amount");

        emit SwapExecuted(msg.sender, USDT, USDTO, amountIn, amountOut);

        return amountOut;
    }

    /**
     * @dev Swap USDTO for USDT using Universal Router (V3 concentrated liquidity pool)
     * @param amountIn Amount of USDTO to swap
     * @param amountOutMin Minimum amount of USDT to receive (slippage protection)
     * @param to Address to receive the USDT tokens
     * @param deadline Transaction deadline timestamp
     * @param fee Fee tier for the pool (e.g., 100 for 0.01%, 500 for 0.05%, 3000 for 0.3%)
     * @return amountOut Amount of USDT received
     */
    function swapUSDTOToUSDT(
        uint256 amountIn,
        uint256 amountOutMin,
        address to,
        uint256 deadline,
        uint24 fee
    ) external returns (uint256 amountOut) {
        require(amountIn > 0, "Amount must be greater than 0");
        require(to != address(0), "Invalid recipient address");
        require(deadline >= block.timestamp, "Deadline has passed");

        // Transfer USDTO from user to this contract
        IERC20(USDTO).transferFrom(msg.sender, address(this), amountIn);

        // Approve Universal Router to spend USDTO
        IERC20(USDTO).approve(address(UNIVERSAL_ROUTER), amountIn);

        // Build V3 path: tokenIn (20 bytes) | fee (3 bytes) | tokenOut (20 bytes)
        bytes memory path = abi.encodePacked(USDTO, fee, USDT);

        // Encode V3 swap input for UniversalRouter
        // Format: (recipient, amountIn, amountOutMinimum, path, payer, isUni)
        bytes memory input = abi.encode(
            to, // recipient
            amountIn, // amountIn
            amountOutMin, // amountOutMinimum
            path, // path as bytes
            address(this), // payer (tokens are in this contract)
            false // isUni = false (Velodrome pool, not Uniswap)
        );

        // Build commands and inputs
        bytes memory commands = abi.encodePacked(
            bytes1(uint8(Commands.V3_SWAP_EXACT_IN))
        );
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = input;

        // Record balance before swap
        uint256 balanceBefore = IERC20(USDT).balanceOf(to);

        // Execute swap
        UNIVERSAL_ROUTER.execute(commands, inputs, deadline);

        // Calculate amount received
        amountOut = IERC20(USDT).balanceOf(to) - balanceBefore;

        require(amountOut >= amountOutMin, "Insufficient output amount");

        emit SwapExecuted(msg.sender, USDTO, USDT, amountIn, amountOut);

        return amountOut;
    }

    /**
     * @dev Generic V2 swap function for Velodrome V2 pools
     * @param tokenIn Address of input token
     * @param tokenOut Address of output token
     * @param amountIn Amount of tokenIn to swap
     * @param amountOutMin Minimum amount of tokenOut to receive
     * @param to Address to receive the output tokens
     * @param deadline Transaction deadline timestamp
     * @param useStable Whether to use stable pool (for Velodrome V2)
     * @return amountOut Amount of tokenOut received
     */
    function swapV2(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMin,
        address to,
        uint256 deadline,
        bool useStable
    ) external returns (uint256 amountOut) {
        require(amountIn > 0, "Amount must be greater than 0");
        require(
            tokenIn != address(0) && tokenOut != address(0),
            "Invalid token address"
        );
        require(to != address(0), "Invalid recipient address");
        require(deadline >= block.timestamp, "Deadline has passed");

        // Transfer tokens from user to this contract
        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);

        // Approve Universal Router to spend tokens
        IERC20(tokenIn).approve(address(UNIVERSAL_ROUTER), amountIn);

        // Build V2 path: tokenIn (20 bytes) | stable (1 byte) | tokenOut (20 bytes)
        bytes memory path = abi.encodePacked(tokenIn, useStable, tokenOut);

        // Encode V2 swap input for UniversalRouter
        // Format: (recipient, amountIn, amountOutMin, path, payerIsUser)
        bytes memory input = abi.encode(
            to, // recipient
            amountIn, // amountIn
            amountOutMin, // amountOutMin
            path, // path as bytes (not array)
            false // payerIsUser = false (tokens already in contract)
        );

        // Build commands and inputs
        bytes memory commands = abi.encodePacked(
            bytes1(uint8(Commands.V2_SWAP_EXACT_IN))
        );
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = input;

        // Record balance before swap
        uint256 balanceBefore = IERC20(tokenOut).balanceOf(to);

        // Execute swap
        UNIVERSAL_ROUTER.execute(commands, inputs, deadline);

        // Calculate amount received
        amountOut = IERC20(tokenOut).balanceOf(to) - balanceBefore;

        require(amountOut >= amountOutMin, "Insufficient output amount");

        emit SwapExecuted(msg.sender, tokenIn, tokenOut, amountIn, amountOut);

        return amountOut;
    }

    /**
     * @dev Generic V3 swap function for concentrated liquidity pools
     * @param tokenIn Address of input token
     * @param tokenOut Address of output token
     * @param amountIn Amount of tokenIn to swap
     * @param amountOutMin Minimum amount of tokenOut to receive
     * @param to Address to receive the output tokens
     * @param deadline Transaction deadline timestamp
     * @param fee Fee tier for the pool (e.g., 100 for 0.01%, 500 for 0.05%, 3000 for 0.3%)
     * @return amountOut Amount of tokenOut received
     */
    function swapV3(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMin,
        address to,
        uint256 deadline,
        uint24 fee
    ) external returns (uint256 amountOut) {
        require(amountIn > 0, "Amount must be greater than 0");
        require(
            tokenIn != address(0) && tokenOut != address(0),
            "Invalid token address"
        );
        require(to != address(0), "Invalid recipient address");
        require(deadline >= block.timestamp, "Deadline has passed");

        // Transfer tokens from user to this contract
        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);

        // Approve Universal Router to spend tokens
        IERC20(tokenIn).approve(address(UNIVERSAL_ROUTER), amountIn);

        // Build V3 path: tokenIn (20 bytes) | fee (3 bytes) | tokenOut (20 bytes)
        bytes memory path = abi.encodePacked(tokenIn, fee, tokenOut);

        // Encode V3 swap input for UniversalRouter
        // Format: (recipient, amountIn, amountOutMinimum, path, payer, isUni)
        bytes memory input = abi.encode(
            to, // recipient
            amountIn, // amountIn
            amountOutMin, // amountOutMinimum
            path, // path as bytes
            address(this), // payer (tokens are in this contract)
            false // isUni = false (Velodrome pool, not Uniswap)
        );

        // Build commands and inputs
        bytes memory commands = abi.encodePacked(
            bytes1(uint8(Commands.V3_SWAP_EXACT_IN))
        );
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = input;

        // Record balance before swap
        uint256 balanceBefore = IERC20(tokenOut).balanceOf(to);

        // Execute swap
        UNIVERSAL_ROUTER.execute(commands, inputs, deadline);

        // Calculate amount received
        amountOut = IERC20(tokenOut).balanceOf(to) - balanceBefore;

        require(amountOut >= amountOutMin, "Insufficient output amount");

        emit SwapExecuted(msg.sender, tokenIn, tokenOut, amountIn, amountOut);

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
        require(balance > 0, "No tokens to recover");
        IERC20(token).transfer(to, balance);
    }
}
