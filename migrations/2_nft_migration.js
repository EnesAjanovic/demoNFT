var NFT = artifacts.require("NFT.sol");

module.exports = function (deployer) {
    // Demo is the contract's name
    deployer.deploy(NFT,'nft','NFT','some url ?',[]);
};