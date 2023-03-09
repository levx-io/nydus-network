// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./LzApp.sol";
import "./NydusERC721.sol";

error DstChainNotFound(uint16 chainId);

interface INydusERC721 is IERC721 {
    function safeMint(
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external;

    function safeMintMany(
        address[] calldata to,
        uint256[] calldata tokenId,
        bytes[] calldata data
    ) external;

    function burn(uint256 tokenId) external;

    function burnMany(uint256[] calldata tokenId) external;
}

contract NydusNetwork is LzApp {
    event UpdateDstAddress(uint16 indexed dstChainId, address indexed dstAddress);

    struct NFTContract {
        uint16 chainId;
        address addr;
    }

    address public immutable implementation;
    mapping(uint16 => address) public dstAddress;
    mapping(address => NFTContract) public mainContract;

    constructor(address _endpoint) LzApp(_endpoint) {
        NydusERC721 nft = new NydusERC721();
        nft.initialize("", "");
        implementation = address(nft);
    }

    function updateDstAddress(uint16 dstChainId, address _dstAddress) external onlyOwner {
        dstAddress[dstChainId] = _dstAddress;

        emit UpdateDstAddress(dstChainId, _dstAddress);
    }

    function transfer(
        address addr,
        uint16 dstChainId,
        uint256 tokenId,
        address to,
        uint256 gas
    ) external payable {
        address dstAddress = dstAddress[dstChainId];
        if (dstAddress == address(0)) revert DstChainNotFound(dstChainId);

        NFTContract memory main = mainContract[addr];
        if (main.chainId == 0) {
            INydusERC721(addr).safeTransferFrom(msg.sender, address(this), tokenId);

            main.chainId = ILayerZeroEndpoint(lzEndpoint).getChainId();
            main.addr = addr;
        } else {
            INydusERC721(addr).burn(tokenId);
        }

        _lzSend(
            dstChainId,
            dstAddress,
            abi.encodePacked(main.chainId, main.addr, tokenId, to),
            payable(msg.sender),
            address(0),
            abi.encodePacked(uint16(1), gas),
            msg.value
        );
    }

    function _blockingLzReceive(
        uint16 _srcChainId,
        bytes calldata _srcAddress,
        uint64 _nonce,
        bytes calldata _payload
    ) internal override {
        (uint16 mainChainId, address mainAddr, uint256 tokenId, address to) = abi.decode(
            _payload,
            (uint16, address, uint256, address)
        );

        if (mainChainId == ILayerZeroEndpoint(lzEndpoint).getChainId()) {
            INydusERC721(mainAddr).safeTransferFrom(address(this), to, tokenId);
        } else {
            bytes32 salt = keccak256(abi.encodePacked(mainChainId, mainAddr));
            address addr = Clones.predictDeterministicAddress(implementation, salt, address(this));
            if (addr.code.length == 0) {
                Clones.cloneDeterministic(implementation, salt);

                mainContract[addr] = NFTContract(mainChainId, mainAddr);
            }
            INydusERC721(addr).safeMint(to, tokenId, "");
        }
    }
}
