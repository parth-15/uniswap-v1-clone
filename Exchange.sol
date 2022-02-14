pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface IFactory {
    function getExchange(address _tokenAddress) external returns(address);
}

interface IExchange {
    function ethToTokenTransfer(uint256 _minTokens, address recipient) external payable;
    function getTokenAmount(uint256 _ethSold) external returns(uint256);
}


contract Exchange is ERC20{
    address public tokenAddress;
    address public factoryAddress;

    constructor(address _tokenAddress) ERC20("Uni token", "UNI") {
        require(_tokenAddress != address(0), "invalid token address");
        tokenAddress = _tokenAddress;
        factoryAddress = msg.sender;
    }

    function addLiquidity(uint _tokenAmount) public payable returns(uint256) {
        if (getReserve() == 0) {
        IERC20 token = IERC20(tokenAddress);
        token.transferFrom(msg.sender, address(this), _tokenAmount);

        uint256 liquidity = address(this).balance;
        _mint(msg.sender, liquidity);
        return liquidity;

        } else {
            uint256 ethReserve = address(this).balance - msg.value;
            uint256 tokenReserve = getReserve();
            uint256 tokenAmount = (msg.value * tokenReserve)/(ethReserve);
            require(_tokenAmount >= tokenAmount, "insufficient funds");

            IERC20 token = IERC20(tokenAddress);
            token.transferFrom(msg.sender, address(this), tokenAmount);

            uint256 liquidity = (totalSupply() * msg.value)/ethReserve;
            _mint(msg.sender, liquidity);
            return liquidity;
        }
    }

    function removeLiquidity(uint256 _amount) public returns(uint256, uint256) {
        require(_amount > 0, "invalid amount");
        uint256 ethAmount = (address(this).balance * _amount)/totalSupply();
        uint256 tokenAmount = (getReserve() * _amount)/totalSupply();

        payable(msg.sender).transfer(ethAmount);
        IERC20(tokenAddress).transfer(msg.sender, tokenAmount);

        return (ethAmount, tokenAmount);
    }

    function getReserve() public view returns(uint256) {
        return IERC20(tokenAddress).balanceOf(address(this));
    } 

    function getAmount(uint256 inputAmount, uint256 inputReserve, uint256 outputReserve) private pure returns(uint256) {
        require(inputReserve > 0 && outputReserve>0, "insufficient reserves");
        uint256 inputAmountWithFee = inputAmount * 99;
        uint256 numerator = inputAmountWithFee * outputReserve;
        uint256 denominator = (inputReserve*100) + inputAmountWithFee;
        return numerator/denominator;
    }

    function getTokenAmount(uint256 _ethSold) public view returns(uint256) {
        require(_ethSold > 0, "ethSold cannot be negative");
        uint tokenReserve = getReserve();
        return getAmount(_ethSold, address(this).balance, tokenReserve);
    }

    function getTokenAmountForTokenToTokenTransfer(address _tokenAddress, uint256 _tokensSold) public returns(uint256) {
        address exchangeAddress = IFactory(factoryAddress).getExchange(_tokenAddress);
        uint256 ethReceived = getEthAmount(_tokensSold);
        uint tokenReceived = IExchange(exchangeAddress).getTokenAmount(ethReceived);
        return tokenReceived;
    }

    function getEthAmount(uint256 _tokenSold) public view returns(uint256) {
        require(_tokenSold > 0, "tokenSold cannot be negative");
        uint256 tokenReserve = getReserve();
        return getAmount(_tokenSold, tokenReserve, address(this).balance);
    }

    function ethToTokenSwap(uint256 _minTokens) public payable {
       ethToToken(_minTokens, msg.sender);
    }

    function ethToTokenTransfer(uint256 _minTokens, address _recipient)
        public
        payable
    {
        ethToToken(_minTokens, _recipient);
    }

    function ethToToken(uint256 _minTokens, address recipient) private {
         uint256 tokenReserve = getReserve();
        uint256 tokensBought = getAmount(msg.value, address(this).balance-msg.value, tokenReserve);
        require(tokensBought >= _minTokens, "cannot ensure minimum tokens");
        IERC20(tokenAddress).transfer(recipient, tokensBought);
    }

    function tokenToEthSwap(uint256 _tokensSold, uint256 _minEth) public {
        uint256 tokenReserve = getReserve();
        uint ethBought = getAmount(_tokensSold, tokenReserve, address(this).balance);
        require(ethBought >= _minEth, "cannot ensure minimum tokens");
        IERC20(tokenAddress).transferFrom(msg.sender, address(this), _tokensSold);
        payable(msg.sender).transfer(ethBought);
    }

    function tokenToTokenSwap(uint256 _tokensSold,uint256 _minTokensBought, address _tokenAddress) public {
        address exchangeAddress = IFactory(factoryAddress).getExchange(_tokenAddress);
        require(exchangeAddress != address(this) && exchangeAddress != address(0), "invalid exchange address");

        uint256 tokenReserve = getReserve();
        uint256 ethBought = getAmount(_tokensSold, tokenReserve, address(this).balance);

        IERC20(tokenAddress).transferFrom(msg.sender, address(this), _tokensSold);
        IExchange(exchangeAddress).ethToTokenTransfer{value: ethBought}(_minTokensBought, msg.sender);
    }
}
