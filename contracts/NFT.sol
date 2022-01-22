pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NFT is ERC721Enumerable, Ownable {
    using Strings for uint256;

    // Company & Developers, used for equal part withdrawal
    address[] public teamAddresses;

    // Settings for IPFS Files, ipfs://<ipfs-folder-identifier>
    string public baseURI;

    uint256 private constant MAIN_SALE_COST = 0.05 ether;
    uint256 private constant PRESALE_COST = 0.04 ether;

    /* Number of different NFT types, and number of NFTs per Type */
    uint8 public constant N_TYPES = 12;
    /*
     * Always set this to "MAX_SUPPLY + 1", this allows to use a more
     * effcient counter and have lower gas fees.
     */
    uint16 public constant MAX_SUPPLY_PER_TYPE = 1000;
    uint16 public constant MAX_SUPPLY_PER_TYPE_PRESALES = 300;

    uint16 public constant INITIAL_SUPPLY_PER_TYPE = 0;
    /* Initial number of minted NFTs per Type */
    uint16[12] public currentSupplyPerType = [
    INITIAL_SUPPLY_PER_TYPE,
    INITIAL_SUPPLY_PER_TYPE,
    INITIAL_SUPPLY_PER_TYPE,
    INITIAL_SUPPLY_PER_TYPE,
    INITIAL_SUPPLY_PER_TYPE,
    INITIAL_SUPPLY_PER_TYPE,
    INITIAL_SUPPLY_PER_TYPE,
    INITIAL_SUPPLY_PER_TYPE,
    INITIAL_SUPPLY_PER_TYPE,
    INITIAL_SUPPLY_PER_TYPE,
    INITIAL_SUPPLY_PER_TYPE,
    INITIAL_SUPPLY_PER_TYPE
    ];

    /*
     * Always set this to "MAX_SUPPLY + 1", this allows to use a more
     * effcient counter and have lower gas fees.
     */
    uint16 public constant MAX_SUPPLY = MAX_SUPPLY_PER_TYPE * N_TYPES;
    uint16 public constant MAX_SUPPLY_PRESALES = MAX_SUPPLY_PER_TYPE_PRESALES * N_TYPES;

    /* Track allowed NFTs minted per wallet */
    uint16 public constant MAX_MINT_AMOUNT_PER_SESSION = 5;
    uint16 public constant NFT_PER_ADDRESS_LIMIT = 10;

    /* Presale activity control */
    bool private preSaleActive = true;

    /* Pause in case of issues */
    bool public paused = true;

    address[] private whitelistedAddresses;

    mapping(address => bool) private isWhitelisted;
    mapping(address => uint16) public addressMintedBalance;

    constructor(
        string memory __name,
        string memory __symbol,
        string memory __initBaseURI,
        address[] memory __teamAddresses
    ) ERC721(__name, __symbol) {
        baseURI = __initBaseURI;
        teamAddresses = __teamAddresses;

        for (uint8 i = 0; i < N_TYPES; i++) {
            currentSupplyPerType[i] = INITIAL_SUPPLY_PER_TYPE;
        }
    }

    function cost() external view returns (uint256) {
        if (preSaleActive) {
            return PRESALE_COST;
        } else {
            return MAIN_SALE_COST;
        }
    }

    function random(uint16 range, uint16 salt) private view returns (uint16) {
        // flagged as weak PRNG: https://github.com/crytic/slither/wiki/Detector-Documentation#weak-PRNG
        return
        uint16(
            (uint256(
            keccak256(
                abi.encodePacked(block.timestamp, block.difficulty, msg.sender, totalSupply(), salt)
            )
        ) % (range))
        );
    }

    function getRandomOfType(uint8 _type, uint16 salt) private view returns (uint16) {
        return random(MAX_SUPPLY_PER_TYPE - currentSupplyPerType[_type], salt);
    }

    function mintOne(uint16 _mintAmount, uint8 _type) internal {
        uint16 typetokenId = 0;
        uint16 fullTokenId = 0;

        for (uint16 i = 1; i <= _mintAmount; i++) {
            typetokenId = getRandomOfType(_type, i);
            addressMintedBalance[msg.sender]++;
            currentSupplyPerType[_type]++;
            fullTokenId = (_type * MAX_SUPPLY_PER_TYPE) + typetokenId;
            while (_exists(fullTokenId)) {
                typetokenId++;
                // flagged as weak PRNG: https://github.com/crytic/slither/wiki/Detector-Documentation#weak-PRNG
                fullTokenId = (_type * MAX_SUPPLY_PER_TYPE) + (typetokenId % MAX_SUPPLY_PER_TYPE);
            }
            _safeMint(msg.sender, fullTokenId);
        }
    }

    // public
    function mintType(uint16 _mintAmount, uint8 _type) external payable {
        require(!paused, "the contract is paused");
        // Restriction of type
        // require(0 <= _type, "Type ID is 0-11 inclusive"); NOT NEEDED; because uint8 is always >=0
        require(_type < N_TYPES, "Type ID is 0-11 inclusive");
        // Mint Amount
        require(_mintAmount > 0, "need to mint at least 1 NFT");
        require(_mintAmount <= MAX_MINT_AMOUNT_PER_SESSION, "max session mint amount exceeded");
        // Total mint amount per address
        require(
            addressMintedBalance[msg.sender] + _mintAmount <= NFT_PER_ADDRESS_LIMIT,
            "max NFT per address exceeded"
        );

        if (preSaleActive) {
            // Flagged for dangerous comparison
            // https://github.com/crytic/slither/wiki/Detector-Documentation#block-timestamp
            require(totalSupply() + _mintAmount <= MAX_SUPPLY_PRESALES, "Max presales supply reached");
            require(
                currentSupplyPerType[_type] + _mintAmount <= MAX_SUPPLY_PER_TYPE_PRESALES,
                "Max presales supply reached"
            );
            require((msg.sender == owner()) || (isWhitelisted[msg.sender]), "user is not whitelisted");
            require(msg.value >= PRESALE_COST * _mintAmount, "insufficient funds");
        } else {
            // Flagged for dangerous comparison
            // https://github.com/crytic/slither/wiki/Detector-Documentation#block-timestamp
            require(totalSupply() + _mintAmount <= MAX_SUPPLY, "Max supply reached");
            require(currentSupplyPerType[_type] + _mintAmount <= MAX_SUPPLY_PER_TYPE, "Max supply reached");
            require(msg.value >= MAIN_SALE_COST * _mintAmount, "insufficient funds");
        }
        mintOne(_mintAmount, _type);
    }

    function mint(uint16 _mintAmount) external payable {
        require(!paused, "the contract is paused");
        // Mint Amount
        require(_mintAmount > 0, "need to mint at least 1 NFT");
        require(_mintAmount <= MAX_MINT_AMOUNT_PER_SESSION, "max session mint amount exceeded");
        // Total mint amount per address
        require(
            addressMintedBalance[msg.sender] + _mintAmount <= NFT_PER_ADDRESS_LIMIT,
            "max NFT per address exceeded"
        );

        if (preSaleActive) {
            require(totalSupply() + _mintAmount <= MAX_SUPPLY_PRESALES, "Max presales supply reached");
            require((msg.sender == owner()) || (isWhitelisted[msg.sender]), "user is not whitelisted");
            require(msg.value >= PRESALE_COST * _mintAmount, "insufficient funds");
        } else {
            require(totalSupply() + _mintAmount <= MAX_SUPPLY, "Max supply reached");
            require(msg.value >= MAIN_SALE_COST * _mintAmount, "insufficient funds");
        }

        uint16 supplyLimit;
        string memory errorMsg;
        if (preSaleActive) {
            supplyLimit = MAX_SUPPLY_PER_TYPE_PRESALES;
            errorMsg = "Max presales supply reached";
        } else {
            supplyLimit = MAX_SUPPLY_PER_TYPE;
            errorMsg = "Max supply reached";
        }

        for (uint16 i = 0; i < _mintAmount; i++) {
            uint8 _type = uint8(random(N_TYPES, i));

            // prevent endless loop by adding a counter
            // check next type, if the current one is not available anymore
            uint8 counter = 0;
            while (currentSupplyPerType[_type] >= supplyLimit && counter < N_TYPES) {
                _type++;
                _type %= N_TYPES;
                counter++;
            }
            require(currentSupplyPerType[_type] + 1 <= supplyLimit, errorMsg);
            mintOne(1, _type);
        }
    }

    function resumePresale() external onlyOwner {
        preSaleActive = true;
    }

    function startMainsale() external onlyOwner {
        preSaleActive = false;
    }

    function pause(bool _state) external onlyOwner {
        paused = _state;
    }

    function resetWhitelist() external onlyOwner {
        // go through all whitelisted users and set them to false
        for (uint256 i = 0; i < whitelistedAddresses.length; i++) {
            isWhitelisted[whitelistedAddresses[i]] = false;
        }
        // reset the full list of whitelisted users
        delete whitelistedAddresses;
    }

    function removeWhitelistedUser(address _user) external onlyOwner {
        // go through all whitelisted users and set them to false
        isWhitelisted[_user] = false;
    }

    function setTeamAddresses(address[] calldata _teamAddresses) external onlyOwner {
        teamAddresses = _teamAddresses;
    }

    function setBaseUri(string calldata _newBaseURI) external onlyOwner {
        baseURI = _newBaseURI;
    }

    function whitelistUsers(address[] calldata _users) external onlyOwner {
        for (uint256 i = 0; i < _users.length; i++) {
            whitelistUser(_users[i]);
        }
    }

    function whitelistUser(address _user) internal onlyOwner {
        whitelistedAddresses.push(_user);
        isWhitelisted[_user] = true;
    }

    function withdraw() external payable onlyOwner {
        // use transfer her instead of send
        // TODO: Problem: https://github.com/crytic/slither/wiki/Detector-Documentation/#calls-inside-a-loop
        // TODO: change to pull over push principle
        // https://eth.wiki/en/howto/smart-contract-safety
        uint256 payPerTeam = address(this).balance / teamAddresses.length;
        for (uint256 i = 0; i < teamAddresses.length; i++) {
            // Function to transfer Ether from this contract to address from input
            // https://ethereum.stackexchange.com/questions/19341/address-send-vs-address-transfer-best-practice-usage
            require(teamAddresses[i] != address(0), "Must not send to zero-address");
            (bool success, ) = teamAddresses[i].call{ value: payPerTeam }("");
            require(success, "Failed to send Ether");
        }
    }
}
