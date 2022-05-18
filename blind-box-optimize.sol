// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "hardhat/console.sol";

contract NftBlinkBox is ERC721, ERC721URIStorage, Ownable {
    // unique token counter
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;

    // store batch details
    struct batch {
        string name; //batch 1
        uint256 release_date; //timestamp
        uint256 total_supply;
        uint256 total_sold;
        uint256 price; // in wei
        uint256 datetimeSoldOut; // If all characters have been sold. (timestamp)
        string thumbnailUri;
        string metadataUri;
        uint256 randomNumber;
    }
    mapping(uint256 => batch) public batchs; // uint256 - batch id

    //set constructor
    constructor() ERC721("My Blind Box - Zai Zainal", "MBB") {}

    // add batch
    function addBatch(
        uint256 _batchId,
        string memory _name,
        uint256 _releaseDate,
        uint256 _totalSupply,
        uint256 _price,
        string memory _thumbnailUri,
        string memory _metadataUri
    ) public onlyOwner {
        // check existing batch
        require(
            batchs[_batchId].total_supply == 0,
            "Batch metadata uri already set."
        );

        batchs[_batchId].name = _name;
        batchs[_batchId].release_date = _releaseDate; //Wednesday, 22 June 2022 00:00:00
        batchs[_batchId].total_supply = _totalSupply;
        batchs[_batchId].total_sold = 0;
        batchs[_batchId].price = _price; // wei
        batchs[_batchId].thumbnailUri = _thumbnailUri;
        batchs[_batchId].metadataUri = _metadataUri;
    }

    // set reveal random number for each batch
    function setReveal(uint256 _batchId) public onlyOwner {
        // check current batch random number
        require(
            batchs[_batchId].randomNumber == 0,
            "Batch random number already set."
        );

        // has meet requirement
        require(
            canBatchReveal(_batchId),
            "Cannot set, batch must sold out, after 3 days and after release date"
        );

        // generate and set 1 random number from 1-10
        batchs[_batchId].randomNumber =
            (uint256(
                keccak256(
                    abi.encodePacked(block.timestamp, block.number, msg.sender)
                )
            ) % 10) +
            1;
    }

    // buy blind box
    // buyer will get token transaction only
    function buyBlindBox(
        uint256 _batchId // 1, 2 & 3
    ) public payable {
        // only buyer allow
        require(msg.sender != owner(), "Owner not allow to buy.");

        // check valid batch Id
        checkBatch(_batchId);

        //check release date
        require(
            block.timestamp >= batchs[_batchId].release_date,
            "Batch still not release yet."
        );

        //check stock - comment if u want testing
        require(
            batchs[_batchId].datetimeSoldOut == 0,
            "Character out of stock."
        );

        // minimum value allowed to be sent
        require(
            msg.value == batchs[_batchId].price,
            "Please enter the same price to continue your purchase."
        ); // in wei

        //update batch sold
        batchs[_batchId].total_sold += 1;

        //check sold out
        if (batchs[_batchId].total_supply == batchs[_batchId].total_sold) {
            // store datetime sold out by batch
            batchs[_batchId].datetimeSoldOut = block.timestamp;
        }

        //set a new token id for the token to be minted
        _tokenIdCounter.increment();
        uint256 tokenID = _tokenIdCounter.current();
        _safeMint(msg.sender, tokenID); //mint the token
    }

    function _burn(uint256 tokenId)
        internal
        override(ERC721, ERC721URIStorage)
    {
        super._burn(tokenId);
    }

    // return uri with random index based on token ID
    function tokenURI(uint256 _tokenID)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        uint256 batchId = getBatch(_tokenID);

        // check current metadata
        require(
            bytes(batchs[batchId].metadataUri).length > 0,
            "Batch metadata is null"
        );

        // if reveal not set yet, return batch thumnail
        if (batchs[batchId].randomNumber == 0) {
            // return thumnail image
            return batchs[batchId].thumbnailUri;
        }

        string memory url = batchs[batchId].metadataUri;
        string memory tokenIdMirror = Strings.toString(
            ((_tokenID + batchs[batchId].randomNumber) %
                batchs[batchId].total_supply) + 1
        );

        return string(abi.encodePacked(url, "/", tokenIdMirror));
    }

    // get batch based on token ID
    function getBatch(uint256 _tokenID) private view returns (uint256) {
        require(_exists(_tokenID), "Token ID not exist.");

        if (_tokenID <= 1111) {
            return 1;
        } else if (_tokenID > 1111 && _tokenID <= 2222) {
            return 2;
        }
        return 3;
    }

    // check batch validation
    function checkBatch(uint256 _batchId) private pure {
        bool validBatch = false;
        if (_batchId != 1 || _batchId != 2 || _batchId != 3) {
            validBatch = true;
        }
        require(validBatch, "Batch Id not Valid.");
    }

    // check requirement batch reveal - must sold out, after 3 days and after release date
    function canBatchReveal(uint256 _batchId) private view returns (bool) {
        uint256 delayDays = 3 days; // 1209600 or 2*7*24*60*60
        uint256 dateCooldown = batchs[_batchId].datetimeSoldOut + delayDays;

        if (
            batchs[_batchId].datetimeSoldOut != 0 && //check sold out
            block.timestamp >= dateCooldown
        ) {
            //check cooldown days
            return true;
        }
        return false;
    }

    // returning the contract's balance in wei
    function getContractBalance() public view onlyOwner returns (uint256) {
        return address(this).balance;
    }

    //tranfer eth from contract to owner
    function ownerWithdraw() public onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    // -------------------------------------------------------------------------------------------
    // NOTE: ignore this section, i just use this as shortcut for testing.
    // -------------------------------------------------------------------------------------------

    //setup testing
    function setupTesting() public onlyOwner {
        batchs[1].name = "Batch 1";
        batchs[1].release_date = 1651334400; //Wednesday, 1 May 2022 00:00:00 - testing only
        batchs[1].total_supply = 2;
        batchs[1].total_sold = 0;
        batchs[1].price = 100000000000000; // wei
        batchs[1]
            .thumbnailUri = "https://gateway.pinata.cloud/ipfs/QmU2DQfKz88LjH25p2pDrEfVndZ7bTXRtsXetE7UBNRrNh";
        batchs[1]
            .metadataUri = "https://ikzttp.mypinata.cloud/ipfs/QmQFkLSQysj94s5GvTHPyzTxrawwtjgiiYS2TBLgrvw8CW";

        batchs[2].name = "Batch 2";
        batchs[2].release_date = 1655827200; //Wednesday, 22 June 2022 00:00:00
        batchs[2].total_supply = 10;
        batchs[2].total_sold = 0;
        batchs[2].price = 100000000000000; // wei
        batchs[1]
            .thumbnailUri = "https://gateway.pinata.cloud/ipfs/QmU2DQfKz88LjH25p2pDrEfVndZ7bTXRtsXetE7UBNRrNh";
        batchs[2]
            .metadataUri = "https://ikzttp.mypinata.cloud/ipfs/QmQFkLSQysj94s5GvTHPyzTxrawwtjgiiYS2TBLgrvw8CW";

        batchs[3].name = "Batch 3";
        batchs[3].release_date = 1656604800; //Wednesday, 1 July 2022 00:00:00
        batchs[3].total_supply = 15;
        batchs[3].total_sold = 0;
        batchs[3].price = 100000000000000; // wei
        batchs[3]
            .thumbnailUri = "https://gateway.pinata.cloud/ipfs/QmU2DQfKz88LjH25p2pDrEfVndZ7bTXRtsXetE7UBNRrNh";
        batchs[3]
            .metadataUri = "https://ikzttp.mypinata.cloud/ipfs/QmQFkLSQysj94s5GvTHPyzTxrawwtjgiiYS2TBLgrvw8CW";
    }

    // set sold out for specific batch
    function manualSoldOutByBatch(uint256 batchId, uint256 _datetimeSoldOut)
        public
        onlyOwner
    {
        batchs[batchId].datetimeSoldOut = _datetimeSoldOut; //1651913531 - Wednesday, 7 May 2022 00:00:00 - testing only
    }
}
