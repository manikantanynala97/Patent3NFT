// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;


import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

// Audited and gas optimized code
contract NFTPatent is ERC721URIStorage
  {
    using Counters for Counters.Counter;
    Counters.Counter totalItems; // Total number of NFTS Items
    uint256 public minimumListingPrice = 0.1 ether;
    address owner;
    AggregatorV3Interface internal priceFeed;

    mapping(uint256 => Patent) private tokenIdToPatent; // mapping of int to struct
    mapping(string => uint256) private categories;
    mapping(address => uint256) public balances;
    mapping(address => uint256) public funds;

    error OnlyOwner();
    error MinimumListingPrice();
    error OnlyNonContractAddress();
    error TokenIdDoesntExist();
    error InsufficentFunds();
    error FailedToTransfer();
    error OnlyCurrentBiderOrOwner();

    struct Patent {
        uint256 tokenId;
        string tokenURI;
        string category;
        address owner;
        address payable currentBider;
        uint256 price;
    }
      
      constructor()  ERC721("NFTPatent","NFTP")
      {
          owner = msg.sender;
          priceFeed = AggregatorV3Interface(0xd0D5e3DB44DE05E9F294BB0a3bEEaF030DE24Ada);
      }
      
      
      modifier onlyOwner()
    {
       if(msg.sender != owner)
       {
           revert OnlyOwner();
       }
       _;
    }
    
    
    
      function setMinimumListingPrice(uint256 _price) external onlyOwner {  
            if(_price >= minimumListingPrice)
            {
                revert MinimumListingPrice();
            }
            minimumListingPrice = _price;
    }
   

    function mint(string calldata _tokenURI, string calldata _category) external {
        totalItems.increment();
        uint256 newItemId = totalItems.current();
        _mint(msg.sender, newItemId);
        _setTokenURI(newItemId, _tokenURI);
        tokenIdToPatent[newItemId] = Patent(
            newItemId,
            _tokenURI,
            _category,
            msg.sender,
            payable(address(0)),
            minimumListingPrice
        );
        ++categories[_category];
        ++balances[msg.sender];
    }

    function getAll() external view returns (Patent[] memory) {
        uint256 _totalItems = totalItems.current();
        uint256 currentIndex;

        Patent[] memory items = new Patent[](_totalItems);
        for (uint256 i ; i < _totalItems;) {
            uint256 currentId = i + 1;
            Patent memory currentItem = tokenIdToPatent[currentId];
            items[currentIndex] = currentItem;
            ++currentIndex;
            unchecked
            {
                ++i;
            }
        }
        return items;
    }

    function getFromCategory(string calldata _category)
        external
        view
        returns (Patent[] memory)
    {
        uint256 _totalItems = categories[_category];
        uint256 currentIndex;
        Patent[] memory items = new Patent[](_totalItems);
        for (uint256 i; i < _totalItems;) {
            uint256 currentId = i + 1;
            if (
                keccak256(
                    abi.encodePacked(tokenIdToPatent[currentId].category)
                ) == keccak256(abi.encodePacked((_category)))
            ) {
                Patent memory currentItem = tokenIdToPatent[currentId];
                items[currentIndex] = currentItem;
                ++currentIndex; 
            }

            unchecked
            {
                ++i;
            }
        }
        return items;
    }

    function getFromAddress(address _user)
        public
        view
        returns (Patent[] memory)
    {
        if(_user == address(this))
        {
            revert OnlyNonContractAddress();
        }
        uint256 currentIndex;
        uint256 _totalItems = balances[_user];
        Patent[] memory items = new Patent[](_totalItems);

        for (uint256 i ;i <_totalItems;) {
            if (tokenIdToPatent[i + 1].owner == _user) {
                Patent memory currentItem = tokenIdToPatent[currentIndex];
                items[currentIndex] = currentItem;
                ++currentIndex;
            }

            unchecked{
                ++i;
            }
        }

        return items;
    }

    function getFromTokenId(uint256 _tokenid)
        external
        view
        returns (Patent memory)
    {
        if(_tokenid == 0  || _tokenid > totalItems.current())
        {
            revert TokenIdDoesntExist();
        }
        return tokenIdToPatent[_tokenid];
    }

    function makeOffer(uint256 _tokenId) external payable {
        Patent memory _tokenIdToPatent = tokenIdToPatent[_tokenId];
         if(_tokenId == 0  || _tokenId > totalItems.current())
        {
            revert TokenIdDoesntExist(); 
        }
         if(msg.value < _tokenIdToPatent.price)
         {
             revert InsufficentFunds();
         }
        if (_tokenIdToPatent.currentBider != address(0)) {
                    funds[_tokenIdToPatent.currentBider] = funds[_tokenIdToPatent.currentBider] + _tokenIdToPatent.price;
        }
        tokenIdToPatent[_tokenId].currentBider = payable(msg.sender);
        tokenIdToPatent[_tokenId].price = msg.value;
    }

    function cancelOffer(uint256 _tokenId) external {
        Patent memory _tokenIdToPatent = tokenIdToPatent[_tokenId];
         if(_tokenId == 0  || _tokenId > totalItems.current())
        {
            revert TokenIdDoesntExist(); 
        }
        if( msg.sender != _tokenIdToPatent.currentBider || msg.sender != _tokenIdToPatent.owner)
        {
            revert OnlyCurrentBiderOrOwner();
        }
        (bool sent, ) =  payable(_tokenIdToPatent.currentBider).call{value: _tokenIdToPatent.price}("");
         if(!sent)
                    {
                        revert FailedToTransfer();
                    }
        tokenIdToPatent[_tokenId].currentBider = payable(address(0));
        tokenIdToPatent[_tokenId].price = minimumListingPrice;
    }

    function approveOffer(uint256 _tokenId) external onlyOwner{
        Patent memory _tokenIdToPatent = tokenIdToPatent[_tokenId];
         if(_tokenId == 0  || _tokenId > totalItems.current())
        {
            revert TokenIdDoesntExist(); 
        }
        tokenIdToPatent[_tokenId].owner =  _tokenIdToPatent.currentBider;
        safeTransferFrom(msg.sender, _tokenIdToPatent.owner, _tokenId,"");
        (bool sent, ) =  payable(msg.sender).call{value: _tokenIdToPatent.price}("");
        if(!sent)
                    {
                        revert FailedToTransfer();
                    }
        tokenIdToPatent[_tokenId].currentBider = payable(address(0));
        tokenIdToPatent[_tokenId].price = minimumListingPrice;
        --balances[msg.sender];
        ++balances[_tokenIdToPatent.owner];
    }


    function withdraw() external 
    {
        uint256 _amount =  funds[msg.sender];
        if(_amount !=0)
        {
            (bool sent,) = payable(msg.sender).call{value : _amount}("");
             if(!sent)
                    {
                        revert FailedToTransfer();
                    }

        }
    } 

      
     function getBalanceOfContract() public  view returns(uint256)
     {
       return address(this).balance;
     } 


     function getBalanceOfContractInUSD() external  view  returns(uint,uint)
     {
        uint _value = getBalanceOfContract();
        (uint nondecimalvalue, uint decimalvalue) = GetValueInDOllar(_value);
        return (nondecimalvalue,decimalvalue);
     }


     function GetLatestPrice()  public view  returns (uint) {
        (
            /*uint80 roundID*/,
            int256 price,
            /*uint startedAt*/,
            /*uint timeStamp*/,
            /*uint80 answeredInRound*/
        ) = priceFeed.latestRoundData();


        return uint(price);
    }

    
    function GetValueInDOllar(uint _maticamount) public view returns(uint,uint){
        uint ValuePrice = GetLatestPrice();
        uint nondecimalvalue =(ValuePrice * _maticamount) / 1e8;
        uint decimalvalue = (ValuePrice * _maticamount) / 1e6;
        return  (nondecimalvalue,decimalvalue);
    }


  }


/*
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
contract NFTPatent is ERC721URIStorage
  {
    AggregatorV3Interface internal priceFeed;
        using Counters for Counters.Counter;
    Counters.Counter totalItems; // Total number of NFTS Items
    uint256 public minimumListingPrice = 0.1 ether;
    address owner;
    mapping(uint256 => Patent) private tokenIdToPatent; // mapping of int to struct
    mapping(string => uint256) private categories;
    mapping(address => uint256) public balances;
    struct Patent {
        uint256 tokenId;
        string tokenURI;
        string category;
        address owner;
        address payable currentBider;
        uint256 price;
    }
      
      constructor()  ERC721("NFTPatent","NFTP")
      {
          owner = msg.sender;
          priceFeed = AggregatorV3Interface(0xd0D5e3DB44DE05E9F294BB0a3bEEaF030DE24Ada);
      }
      
      
      modifier onlyOwner()
    {
      require(msg.sender == owner,"Only Owner can call this function");
      _;  
    }
    
    
    
      function setMinimumListingPrice(uint256 _price) public onlyOwner {
        minimumListingPrice = _price;
    }
   
    function mint(string memory _tokenURI, string memory _category) public {
        totalItems.increment();
        uint256 newItemId = totalItems.current();
        _mint(msg.sender, newItemId);
        _setTokenURI(newItemId, _tokenURI);
        tokenIdToPatent[totalItems.current()] = Patent(
            totalItems.current(),
            _tokenURI,
            _category,
            msg.sender,
            payable(address(0)),
            minimumListingPrice
        );
        categories[_category] += 1;
        balances[msg.sender] += 1;
    }
    function getAll() public view returns (Patent[] memory) {
        uint256 _totalItems = totalItems.current();
        uint256 currentIndex = 0;
        Patent[] memory items = new Patent[](_totalItems);
        for (uint256 i = 0; i < totalItems.current(); i++) {
            uint256 currentId = i + 1;
            Patent storage currentItem = tokenIdToPatent[currentId];
            items[currentIndex] = currentItem;
            currentIndex += 1;
        }
        return items;
    }
    function getFromCategory(string memory _category)
        public
        view
        returns (Patent[] memory)
    {
        uint256 _totalItems = categories[_category];
        uint256 currentIndex = 0;
        Patent[] memory items = new Patent[](_totalItems);
        for (uint256 i = 0; i < totalItems.current(); i++) {
            uint256 currentId = i + 1;
            if (
                keccak256(
                    abi.encodePacked(tokenIdToPatent[currentId].category)
                ) == keccak256(abi.encodePacked((_category)))
            ) {
                Patent storage currentItem = tokenIdToPatent[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }
    function getFromAddress(address _user)
        public
        view
        returns (Patent[] memory)
    {
        require(
            address(this) != _user,
            "User shouldnot be the contract address"
        );
        uint256 currentIndex = 0;
        uint256 _totalItems = balances[_user];
        Patent[] memory items = new Patent[](_totalItems);
        for (uint256 i = 0; i < totalItems.current(); i++) {
            if (tokenIdToPatent[i + 1].owner == _user) {
                Patent storage currentItem = tokenIdToPatent[currentIndex];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }
    function getFromTokenId(uint256 _tokenid)
        public
        view
        returns (Patent memory)
    {
        require(
            _tokenid > 0 && _tokenid <= totalItems.current(),
            "Token Id doesnt exist"
        );
        return tokenIdToPatent[_tokenid];
    }
    function makeOffer(uint256 _tokenId) public payable {
        require(
            _tokenId > 0 && _tokenId <= totalItems.current(),
            "Token Id doesnt exist"
        );
        require(
            msg.value > tokenIdToPatent[_tokenId].price,
            "Bid is not enough"
        );
        if (tokenIdToPatent[_tokenId].currentBider != address(0)) {
                    (bool sent, ) =  payable(tokenIdToPatent[_tokenId].currentBider).call{value: tokenIdToPatent[_tokenId].price}("");
                      require(sent, "Failed to send Ether");
        }
        tokenIdToPatent[_tokenId].currentBider = payable(msg.sender);
        tokenIdToPatent[_tokenId].price = msg.value;
    }
    function cancelOffer(uint256 _tokenId) public {
        require(
            _tokenId > 0 && _tokenId <= totalItems.current(),
            "Token Id doesnt exist"
        );
        require(
            msg.sender == tokenIdToPatent[_tokenId].currentBider ||
                msg.sender == tokenIdToPatent[_tokenId].owner,
            "Only currentBider and owner can cancel the offer"
        );
        (bool sent, ) =  payable(tokenIdToPatent[_tokenId].currentBider).call{value: tokenIdToPatent[_tokenId].price}("");
          require(sent, "Failed to send Ether");
        tokenIdToPatent[_tokenId].currentBider = payable(address(0));
        tokenIdToPatent[_tokenId].price = minimumListingPrice;
    }
    function approveOffer(uint256 _tokenId) public {
        require(
            _tokenId > 0 && _tokenId <= totalItems.current(),
            "Token Id doesnt exist"
        );
        require(
            msg.sender == tokenIdToPatent[_tokenId].owner,
            "Only Owner can approve and sell the NFT"
        );
        tokenIdToPatent[_tokenId].owner = tokenIdToPatent[_tokenId]
            .currentBider;
        transferFrom(msg.sender, tokenIdToPatent[_tokenId].owner, _tokenId);
        (bool sent, ) =  payable(msg.sender).call{value: tokenIdToPatent[_tokenId].price}("");
          require(sent, "Failed to send Ether");
        tokenIdToPatent[_tokenId].currentBider = payable(address(0));
        tokenIdToPatent[_tokenId].price = minimumListingPrice;
        balances[msg.sender] -= 1;
        balances[tokenIdToPatent[_tokenId].owner] += 1;
    }
      
     function getBalanceOfContract() public view returns(uint256)
     {
       return address(this).balance;
     } 
     function getBalanceOfContractInUSD() public view  returns(uint,uint)
     {
        uint _value = getBalanceOfContract();
        (uint nondecimalvalue, uint decimalvalue) = GetValueInDOllar(_value);
        return (nondecimalvalue,decimalvalue);
     }
     function GetLatestPrice()  public view  returns (uint) {
        (
            uint80 roundID,
            int256 price,
            uint startedAt,
            uint timeStamp,
            uint80 answeredInRound
        ) = priceFeed.latestRoundData();
        return uint(price);
    }
    
    function GetValueInDOllar(uint _maticamount) public view returns(uint,uint){
        uint ValuePrice = GetLatestPrice();
        uint nondecimalvalue =(ValuePrice * _maticamount) / 1e8;
        uint decimalvalue = (ValuePrice * _maticamount) / 1e6;
        return  (nondecimalvalue,decimalvalue);
    }
  }
*/
