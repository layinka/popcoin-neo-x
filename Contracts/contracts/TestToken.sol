// SPDX-License-Identifier: AGPL-1.0
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestToken is ERC20 {
	uint8 decimalPlaces;

	constructor(string memory name, string memory symbol,  uint8 _decimals) ERC20(name, symbol) {
		decimalPlaces=_decimals;

		_mint(msg.sender, 100000000 * 10 ** decimalPlaces);
		_mint(0xa55980aB0C3aeFB871af97462CdbBECB41aEed09, 10000 * 10 ** decimalPlaces);
		_mint (0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266, 10000 * 10 ** decimalPlaces);

		_mint(0x70997970C51812dc3A010C7d01b50e0d17dc79C8, 10000 * 10 ** decimalPlaces);
		_mint (0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC, 10000 * 10 ** decimalPlaces);
	}



	function giveMe(uint256 amount) public {
		_mint(msg.sender, amount);
	}

	function decimals() public view virtual override returns (uint8) {
		return decimalPlaces;
	}
}
