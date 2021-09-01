// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "../openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract ExposureNetwork is ERC20 {

    /**
     * Structure describing one record of exposure, including the amount and an exiry time. The exposure cannot
     * be reduced before the expiry.
     */
    struct Exposure {
        uint256 amount;
        uint expiry;
    }
    
    /**
     * The structure that stores the exposure network. The first address is the giver
     * being exposed. The second address is the taker that can take the exposure.
     */
    mapping(address => mapping(address => Exposure)) private _exposures;
    
    /**
     * The address that is the owner of the contract.
     * 
     * Is given the initial supply and then takes half the coins taken by any user.
     * 
     */ 
    address private _owner;

    function _get_owner() internal view returns (address){
        return _owner;
    }    
    
    /** 
     * Helper function to get current time, that is virtual to allow for mocking
     * to test time related functions.
     */
    function _get_time() internal virtual returns (uint) {
        return block.timestamp;
    }
    
    function _update(address giver, address taker, Exposure memory exp) private {
        _exposures[giver][taker] = exp;
        emit UpdateExposure(giver, taker, exp.amount);
    }
    
    /**
     *  Allows a giver to increase their exposure to a taker, by a certain amount. The final
     * exposure must be within the current balance of the giver.
     * 
     */ 
    function increaseExposure(address taker, uint256 amount) public {
        address giver = _msgSender();
        uint256 balance = balanceOf(giver);
        
        Exposure memory exp = _exposures[giver][taker];
        
        // Check that the final exposure does not exceed balance.
        require(amount > 0, "An update must change the exposure." );
        require(exp.amount + amount <= balance, "Updated exposure must be within balance.");
        
        // Update the exposure for this pair.
        // TODO: constant 14 days of extending expiry.
        _update( giver, taker,
            Exposure(exp.amount + amount, _get_time() + 14 days));
    }
    
    
    /**
     * Utility function to reduce exposure.
     * 
     * Used when giver choses to reduce exposure of when a taker takes some of the 
     * available exposure.
     * 
     */ 
    function _reduce(address giver, address taker, uint256 amount) private {
        Exposure memory exp = _exposures[giver][taker];
        
        // The amount must be smaller than the current exposure.
        if (amount > exp.amount) {
            amount = exp.amount;
        }
        
        _update( giver, taker,
            Exposure(exp.amount - amount, exp.expiry));
    }
    
    /**
     *  A giver choses to reduce their exposure to a taker.
     * 
     * This can only be done after the expiry time in the exposure, and the new
     * exposure has to be within the taker balance.
     * 
     */ 
    function reduceExposure(address taker, uint256 amount) public {
        address giver = _msgSender();
        
        // Cannot reduce exposure before the expiry time.
        require( currentExposureExpiry(giver, taker) < _get_time(), "Can only reduce exposure after exposure expiry.");
    
        // Can only update exposures to available balance.
        require (amount <= currentExposureAmount(giver, taker), "Can only update exposure within the balance.");
    
        _reduce(giver, taker, amount);
    }

    /**
     *  Reads the current exposure amount between a giver and a taker.
     */ 
    function currentExposureAmount(address giver, address taker) public view returns (uint256) {
        Exposure memory exp = _exposures[giver][taker];
        uint256 balance = balanceOf(giver);
        if (exp.amount > balance) {
            return balance;
        }
        else {
            return exp.amount; 
        }
    }

    /**
     *  Reads the current expiry of the exposure between a giver and a taker.
     */ 
    function currentExposureExpiry(address giver, address taker) public view returns (uint) {
        Exposure memory exp = _exposures[giver][taker];
        return exp.expiry;
    }

    /**
     * A taker takes a number of tokens within the exposure of a giver.
     * 
     */ 
    function takeExposure(address giver, uint256 amount) public {
         address taker = _msgSender();
         
         // Cannot take more than is available.
        require(amount > 0, "Take must take something.");
        require(amount <= currentExposureAmount(giver, taker), "Can only take up to the available exposure.");
        
        // Work out the split: half go to taker, and half to contract owner.
        uint256 to_taker_amount = amount / 2;
        uint256 to_owner_amount = amount - to_taker_amount;
        
        // Update the record, so that taker cannot keep taking.
        _reduce(giver, taker, amount);
        
        // Q: should we automatically reduce exposure the other way to avoid retaliation?
        
        // Now execute the transfers.
        _transfer(giver, _owner, to_owner_amount);
        _transfer(giver, taker, to_taker_amount);
        
        emit Take(giver, taker, amount);
    }

    /**
     * @dev Mints `initialSupply` amount of token and transfers them to `owner`.
     *
     * See {ERC20-constructor}.
     */
    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        address owner
    ) ERC20(name, symbol) {
        _owner = owner;
        _mint(owner, initialSupply);
    }
    
    /**
     * The event triggers when the exposure between two users changes.
     */ 
    event UpdateExposure(address indexed giver, address indexed taker, uint amount);
    /**
     *  The event triggers when a taker takes from a giver.
     */ 
    event Take(address indexed giver, address indexed taker, uint amount);
    
}

contract ExposureNetworkTest is ExposureNetwork {
   
   uint current_time;
   
   function _test_set_time(uint t) public {
       current_time = t;
   }
   
    function _get_time() internal override returns (uint) {
        return current_time;
    } 
    
    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        address owner
    ) ExposureNetwork(name, symbol, initialSupply, owner) {}
    
}
