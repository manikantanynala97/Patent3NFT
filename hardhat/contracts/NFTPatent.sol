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
    Counters.Counter  ItemsSold ; // Total Items Sold till now 
    Counters.Counter  TotalItems ; // Total number of NFTS Items 
    uint256 public MinimumListingPrice = 1 ether;  // Since polygon is evm compatible so 1 matic = 1 ether
    address Owner;
      
     mapping(uint256 => Patent) private TokenIdToPatent; // mapping of int to struct 
     mapping(string => uint256) private Categories;
     mapping(address=>uint256) public balances;
    
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
          Owner = msg.sender;
          priceFeed = AggregatorV3Interface(0xd0D5e3DB44DE05E9F294BB0a3bEEaF030DE24Ada);
      }
      
      
      modifier onlyOwner()
    {
      require(msg.sender == Owner,"Only Owner can call this function");
      _;  
    }
    
    
    
    function UpdateListingPrice(uint256 _price) public onlyOwner
   {
      MinimumListingPrice = _price;
   }

     function GetListingPrice() public view returns(uint256)
   {
       return MinimumListingPrice;
   }


    function MintNFT(uint256 _price,string memory _TokenURI,string memory  _category) public  
    {
       require(_price >=MinimumListingPrice,"The price should be atleast minimum");
       TotalItems.increment();
        uint256 newItemId = TotalItems.current();
        _mint(msg.sender, newItemId);
        _setTokenURI(newItemId, _TokenURI);
          TokenIdToPatent[TotalItems.current()] = Patent(
            TotalItems.current(),
            _TokenURI,
            _category,
            msg.sender,
            payable(address(0)),
            MinimumListingPrice
        );
       Categories[_category]+=1;
       balances[msg.sender]+=1;
    }
    
    
        function getAll() public view returns(Patent[] memory)
    {
            uint256 _TotalItems = TotalItems.current() ;
            uint256 currentIndex = 0;

            Patent[] memory items = new Patent[](_TotalItems);
            
            for (uint256 i = 0; i < _TotalItems; i++) {
             uint256 currentId = i + 1;
             Patent storage currentItem = TokenIdToPatent[currentId];
             items[currentIndex] = currentItem;
             currentIndex += 1;
      }
             return items;
    }


      function getAccordingToCategory(string memory _category) public view returns(Patent[] memory)
      {
           uint256 _TotalItems = Categories[_category];
           uint256 currentIndex = 0;
           Patent[] memory items = new Patent[](_TotalItems);
           uint256 totalItems = TotalItems.current()
           for(uint256 i=0;i< totalItems;i++)
           {
               uint256 currentId = i + 1;
               if(keccak256(abi.encodePacked(TokenIdToPatent[currentId].category))== keccak256(abi.encodePacked((_category))))
               {
                    Patent storage currentItem = TokenIdToPatent[currentId];
                    items[currentIndex] = currentItem;
                    currentIndex += 1;
               }
           }
           return items;
      }
    
    
      function getFromAddress(address _user) public view returns(Patent[] memory )
      {
            require(address(this) != _user,"User shouldnot be the contract address");
            uint256 currentIndex = 0;
            uint256 _TotalItems = balances[_user];
            Patent[] memory items = new Patent[](_TotalItems);
            uint256 totalItems = TotalItems.current();
            for(uint256 i=0;i< totalItems;i++)
            {
                if(TokenIdToPatent[i+1].owner == _user )
                {
                    Patent storage currentItem = TokenIdToPatent[i+1];
                    items[currentIndex] = currentItem;
                    currentIndex += 1;
                }
            }
            
            return items;
            
      }
      
      
      function getAccordingToTokenId(uint256 _tokenid) public view returns(Patent memory)
      {
            require(_tokenid > 0  && _tokenid <=TotalItems.current(),"Token Id doesnt exist");
            return TokenIdToPatent[_tokenid];
      }
      
       function makeOffer(uint256 _tokenId) public payable
    {
       require(_tokenId > 0  && _tokenId <=TotalItems.current(),"Token Id doesnt exist");
       require(msg.value > TokenIdToPatent[_tokenId].price,"Bid is not enough");
       if(TokenIdToPatent[_tokenId].currentBider != address(0))
       {
       (bool sent, ) = TokenIdToPatent[_tokenId].currentBider.call{value: TokenIdToPatent[_tokenId].price}("");
       require(sent, "Failed to send Ether");
       }
       TokenIdToPatent[_tokenId].currentBider = payable(msg.sender);
       TokenIdToPatent[_tokenId].price = msg.value;
    }
    
    
      function CancelOffer(uint256 _tokenId) public 
      {
         require(_tokenId > 0  && _tokenId <=TotalItems.current(),"Token Id doesnt exist");
         require(msg.sender == TokenIdToPatent[_tokenId].currentBider,"Only current_bider can cancel the offer");
         (bool sent, ) = TokenIdToPatent[_tokenId].currentBider.call{value: TokenIdToPatent[_tokenId].price}("");
         require(sent, "Failed to send Ether");
         //tronWeb.transactionBuilder.sendTrx(address(this),TokenIdToNFTItem[_tokenId].price, TokenIdToNFTItem[_tokenId].current_bider );
         TokenIdToPatent[_tokenId].currentBider = payable(address(0));
         TokenIdToPatent[_tokenId].price = MinimumListingPrice;
      }
    
    
      
        function approveOffer(uint256 _tokenId) public 
    {
       require(_tokenId > 0  && _tokenId <=TotalItems.current(),"Token Id doesnt exist");
       require(msg.sender == TokenIdToPatent[_tokenId].owner,"Only owner can approve and sell the NFT");
       TokenIdToPatent[_tokenId].owner= TokenIdToPatent[_tokenId].currentBider;
       transferFrom(msg.sender,TokenIdToPatent[_tokenId].owner,_tokenId);
       (bool sent, ) =  payable(msg.sender).call{value: TokenIdToPatent[_tokenId].price}("");
       //tronWeb.transactionBuilder.sendTrx(address(this),TokenIdToNFTItem[_tokenId].price, msg.sender );
       require(sent, "Failed to send Ether");
       TokenIdToPatent[_tokenId].owner = address(0);
       TokenIdToPatent[_tokenId].currentBider = payable(address(0));
       TokenIdToPatent[_tokenId].price = 0 ether;
       ItemsSold.increment();
       balances[msg.sender]-=1;
       balances[TokenIdToPatent[_tokenId].owner]+=1;
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


    receive() external payable
    {

    }

    
      
  }
  
  
