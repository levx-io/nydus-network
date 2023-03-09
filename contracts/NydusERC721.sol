// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";

contract NydusERC721 is ERC721Upgradeable {
    error Forbidden();
    error InvalidParams();

    address public network;

    modifier onlyNetwork() {
        if (msg.sender != network) revert Forbidden();
        _;
    }

    function initialize(string memory _name, string memory _symbol) external initializer {
        __ERC721_init(_name, _symbol);
        network = msg.sender;
    }

    function safeMint(
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external onlyNetwork {
        _safeMint(to, tokenId, data);
    }

    function safeMintMany(
        address[] calldata to,
        uint256[] calldata tokenId,
        bytes[] calldata data
    ) external onlyNetwork {
        if (to.length != tokenId.length || to.length != data.length) revert InvalidParams();

        for (uint256 i = 0; i < to.length; i++) {
            _safeMint(to[i], tokenId[i], data[i]);
        }
    }

    function burn(uint256 tokenId) external onlyNetwork {
        _burn(tokenId);
    }

    function burnMany(uint256[] calldata tokenId) external onlyNetwork {
        for (uint256 i; i < tokenId.length; ) {
            _burn(tokenId[i]);

            unchecked {
                ++i;
            }
        }
    }
}
