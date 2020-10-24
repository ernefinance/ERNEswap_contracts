pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

contract ErneNest is ERC20("ErneNest", "xERNE"){
    using SafeMath for uint256;
    IERC20 public erne;

    // Define the Erne token contract
    constructor(IERC20 _erne) public {
        erne = _erne;
    }

    // Enter the Nest. Pay some ERNEs. Earn some shares.
    // Locks Erne and mints xErne
    function enter(uint256 _amount) public {
        // Gets the amount of Erne locked in the contract
        uint256 totalErne = erne.balanceOf(address(this));
        // Gets the amount of xErne in existence
        uint256 totalShares = totalSupply();
        // If no xErne exists, mint it 1:1 to the amount put in
        if (totalShares == 0 || totalErne == 0) {
            _mint(msg.sender, _amount);
        } 
        // Calculate and mint the amount of xErne the Erne is worth. The ratio will change overtime, as xErne is burned/minted and Erne deposited + gained from fees / withdrawn.
        else {
            uint256 what = _amount.mul(totalShares).div(totalErne);
            _mint(msg.sender, what);
        }
        // Lock the Erne in the contract
        erne.transferFrom(msg.sender, address(this), _amount);
    }

    // Leave the Nest. Claim back your ERNEs.
    // Unclocks the staked + gained Erne and burns xErne
    function leave(uint256 _share) public {
        // Gets the amount of xErne in existence
        uint256 totalShares = totalSupply();
        // Calculates the amount of Erne the xErne is worth
        uint256 what = _share.mul(erne.balanceOf(address(this))).div(totalShares);
        _burn(msg.sender, _share);
        erne.transfer(msg.sender, what);
    }
}