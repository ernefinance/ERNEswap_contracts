pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./ERNEswap/interfaces/IERNEswapV2ERC20.sol";
import "./ERNEswap/interfaces/IERNEswapV2Pair.sol";
import "./ERNEswap/interfaces/IERNEswapV2Factory.sol";

contract ErneMaker {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IERNEswapV2Factory public factory;
    address public nest;
    address public erne;
    address public weth;

    constructor(IERNEswapV2Factory _factory, address _nest, address _erne, address _weth) public {
        factory = _factory;
        erne = _erne;
        nest = _nest;
        weth = _weth;
    }

    function convert(address token0, address token1) public {
        // At least we try to make front-running harder to do.
        require(msg.sender == tx.origin, "do not convert from contract");
        IERNEswapV2Pair pair = IERNEswapV2Pair(factory.getPair(token0, token1));
        pair.transfer(address(pair), pair.balanceOf(address(this)));
        pair.burn(address(this));
        // First we convert everything to WETH
        uint256 wethAmount = _toWETH(token0) + _toWETH(token1);
        // Then we convert the WETH to Erne
        _toERNE(wethAmount);
    }

    // Converts token passed as an argument to WETH
    function _toWETH(address token) internal returns (uint256) {
        // If the passed token is Erne, don't convert anything
        if (token == erne) {
            uint amount = IERC20(token).balanceOf(address(this));
            _safeTransfer(token, nest, amount);
            return 0;
        }
        // If the passed token is WETH, don't convert anything
        if (token == weth) {
            uint amount = IERC20(token).balanceOf(address(this));
            _safeTransfer(token, factory.getPair(weth, erne), amount);
            return amount;
        }
        // If the target pair doesn't exist, don't convert anything
        IERNEswapV2Pair pair = IERNEswapV2Pair(factory.getPair(token, weth));
        if (address(pair) == address(0)) {
            return 0;
        }
        // Choose the correct reserve to swap from
        (uint reserve0, uint reserve1,) = pair.getReserves();
        address token0 = pair.token0();
        (uint reserveIn, uint reserveOut) = token0 == token ? (reserve0, reserve1) : (reserve1, reserve0);
        // Calculate information required to swap
        uint amountIn = IERC20(token).balanceOf(address(this));
        uint amountInWithFee = amountIn.mul(997);
        uint numerator = amountInWithFee.mul(reserveOut);
        uint denominator = reserveIn.mul(1000).add(amountInWithFee);
        uint amountOut = numerator / denominator;
        (uint amount0Out, uint amount1Out) = token0 == token ? (uint(0), amountOut) : (amountOut, uint(0));
        // Swap the token for WETH
        _safeTransfer(token, address(pair), amountIn);
        pair.swap(amount0Out, amount1Out, factory.getPair(weth, erne), new bytes(0));
        return amountOut;
    }

    // Converts WETH to Erne
    function _toERNE(uint256 amountIn) internal {
        IERNEswapV2Pair pair = IERNEswapV2Pair(factory.getPair(weth, erne));
        // Choose WETH as input token
        (uint reserve0, uint reserve1,) = pair.getReserves();
        address token0 = pair.token0();
        (uint reserveIn, uint reserveOut) = token0 == weth ? (reserve0, reserve1) : (reserve1, reserve0);
        // Calculate information required to swap
        uint amountInWithFee = amountIn.mul(997);
        uint numerator = amountInWithFee.mul(reserveOut);
        uint denominator = reserveIn.mul(1000).add(amountInWithFee);
        uint amountOut = numerator / denominator;
        (uint amount0Out, uint amount1Out) = token0 == weth ? (uint(0), amountOut) : (amountOut, uint(0));
        // Swap WETH for Erne
        pair.swap(amount0Out, amount1Out, nest, new bytes(0));
    }

    // Wrapper for safeTransfer
    function _safeTransfer(address token, address to, uint256 amount) internal {
        IERC20(token).safeTransfer(to, amount);
    }
}