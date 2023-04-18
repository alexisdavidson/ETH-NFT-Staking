// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
// import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
// import "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";
import "./RewardNFT.sol";
import "./PlaceholderNFT.sol";
import "./ReentrancyGuard.sol";
import "./MyOwnable.sol";

contract NFTStakerV3 is ERC721Holder, MyOwnable, ReentrancyGuard {
    ERC721[] public stakedNfts; // 10,000 Quirklings, 5,000 Quirkies

    PlaceholderNFT public placeholderNft;
    RewardNFT public rewardNft;

    uint256 stakeMinimum;
    uint256 stakeMaximum;
    // uint256 stakePeriod = 30 * 24 * 60 * 60; // 30 Days
    uint256 stakePeriod;
   
    mapping(uint256 => bool) public claimedNfts;

    struct Staking {
        address stakerAddress;
        uint256 placeholderTokenId;
        uint256 timestamp;
    }

    struct Staker { 
        uint256[] tokenIds;
        uint256[] placeholderTokenIds; // unused
        uint256[] timestamps; // unused
    }

    mapping(address => Staker) private stakers;
    address[] stakersAddresses;

    modifier notInitialized() {
        require(!initialized, "Contract instance has already been initialized");
        _;
    }

    bool private initialized;

    mapping(uint256 => Staking) private tokenIdsToStaking;

    event StakeSuccessful(uint256 tokenId, uint256 timestamp);

    event UnstakeSuccessful(uint256 tokenId, bool rewardClaimed);

    function initialize(
        uint256 _stakeMinimum,
        uint256 _stakeMaximum,
        uint256 _stakingPeriod,
        address _ownerAddress,
        address[] memory _stakedNfts,
        address _placeholderNftAddress,
        address _rewardNftAddress
    ) public nonReentrant notInitialized {
        stakeMinimum = _stakeMinimum;
        stakeMaximum = _stakeMaximum;
        stakePeriod = _stakingPeriod;

        _transferOwnership(_msgSender());

        for (uint256 i = 0; i < _stakedNfts.length; i++) {
            stakedNfts.push(ERC721(_stakedNfts[i]));
        }

        placeholderNft = PlaceholderNFT(_placeholderNftAddress);
        rewardNft = RewardNFT(_rewardNftAddress);

        transferOwnership(_ownerAddress);
        initialized = true;
    }

    function tokenIdToCollectionIndex(
        uint256 _tokenId
    ) public pure returns (uint256) {
        if (_tokenId < 10000) return 0;
        return 1;
    }

    // take list of stake Nft, mint same amount of placeHolderNft
    // burning optional (only if there)
    function stake(uint256[] memory _tokenIds) public nonReentrant {
        uint256 _quantity = _tokenIds.length;
        require(
            _quantity >= stakeMinimum && _quantity <= stakeMaximum,
            "Stake amount incorrect"
        );

        for (uint256 i = 0; i < _quantity; i++) {
            require(claimedNfts[_tokenIds[i]] == false, "NFT already claimed");
            require(
                stakedNfts[tokenIdToCollectionIndex(_tokenIds[i])].ownerOf(
                    _tokenIds[i] % 10_000
                ) == msg.sender,
                "You do not own this Nft"
            );
        }

        for (uint256 i = 0; i < _quantity; i++) {
            stakedNfts[tokenIdToCollectionIndex(_tokenIds[i])].safeTransferFrom(
                    msg.sender,
                    address(this),
                    _tokenIds[i] % 10_000
                );
            uint256 _placeholderTokenId = placeholderNft.mintNFT(
                msg.sender,
                _tokenIds[i]
            );

            tokenIdsToStaking[_tokenIds[i]] = Staking(msg.sender, _placeholderTokenId, block.timestamp);

            stakers[msg.sender].tokenIds.push(_tokenIds[i]);
            stakers[msg.sender].placeholderTokenIds.push(_placeholderTokenId);
            stakers[msg.sender].timestamps.push(block.timestamp);

            emit StakeSuccessful(_tokenIds[i], block.timestamp);
        }

        stakersAddresses.push(msg.sender);
    }

    function unstake(uint256[] memory _tokenIds) public nonReentrant {
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            Staking memory staking = tokenIdsToStaking[_tokenIds[i]];
            require(isTokenStaked(_tokenIds[i]) && tokenIdsToStaking[_tokenIds[i]].stakerAddress == msg.sender,
                    "Index not found for this staker.");

            stakedNfts[tokenIdToCollectionIndex(_tokenIds[i])].safeTransferFrom(
                    address(this),
                    msg.sender,
                    _tokenIds[i] % 10_000
                );
            if (
                placeholderNft.ownerOf(
                    staking.placeholderTokenId
                ) == msg.sender
            ) {
                placeholderNft.safeTransferFrom(
                    msg.sender,
                    0x000000000000000000000000000000000000dEaD,
                    staking.placeholderTokenId
                );
            }

            bool stakingTimeElapsed = block.timestamp >
                staking.timestamp + stakePeriod;

            if (stakingTimeElapsed) {
                rewardNft.mintNFT(msg.sender, _tokenIds[i]);
                claimedNfts[_tokenIds[i]] = true;
            }
        }
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            Staking memory staking = tokenIdsToStaking[_tokenIds[i]];
            require(isTokenStaked(_tokenIds[i]) && tokenIdsToStaking[_tokenIds[i]].stakerAddress == msg.sender,
                    "Index not found for this staker.");
            bool stakingTimeElapsed = block.timestamp >
                staking.timestamp + stakePeriod;
            
            tokenIdsToStaking[_tokenIds[i]] = Staking(msg.sender, 0, 0);
            
            removeStakerElement(
                msg.sender,
                _tokenIds[i],
                stakers[msg.sender].tokenIds.length - 1
            );

            emit UnstakeSuccessful(_tokenIds[i], stakingTimeElapsed);
        }
    }

    function removeStakerElement(
        address _user,
        uint256 _tokenIndex,
        uint256 _lastIndex
    ) internal {
        
        uint256 _indexToRemove = 0;
        uint256 _tokensLength = stakers[_user].tokenIds.length;
        for(uint256 i = 0; i < _tokensLength; i++) {
            if (stakers[_user].tokenIds[i] == _tokenIndex) {
                _indexToRemove = i;
            }
        }
        stakers[_user].tokenIds[_indexToRemove] = stakers[_user].tokenIds[_lastIndex];
        stakers[_user].tokenIds.pop();
        stakers[_user].placeholderTokenIds[_indexToRemove] = stakers[_user].placeholderTokenIds[_lastIndex];
        stakers[_user].placeholderTokenIds.pop();
        stakers[_user].timestamps[_indexToRemove] = stakers[_user].timestamps[_lastIndex];
        stakers[_user].timestamps.pop();

        // stakers[_user].timestamps[_tokenIndex] = stakers[_user].timestamps[
        //     _lastIndex
        // ];
        // stakers[_user].timestamps.pop();

        // stakers[_user].tokenIds[_tokenIndex] = stakers[_user].tokenIds[
        //     _lastIndex
        // ];
        // stakers[_user].tokenIds.pop();

        // stakers[_user].placeholderTokenIds[_tokenIndex] = stakers[_user]
        //     .placeholderTokenIds[_lastIndex];
        // stakers[_user].placeholderTokenIds.pop();
    }

    function isTokenStaked(uint256 _tokenId) public view returns (bool) {
        return tokenIdsToStaking[_tokenId].timestamp != 0 || tokenIdsToStaking[_tokenId].placeholderTokenId != 0;
    }

    function getPlaceholderTokenIds(
        address _user
    ) public view returns (uint256[] memory) {
        return stakers[_user].placeholderTokenIds;
    }

    function getStakedTokens(
        address _user
    ) public view returns (uint256[] memory tokenIds) {
        return stakers[_user].tokenIds;
    }

    // todo: replace later, maybe by getStakedTimestamp(uint256 _tokenId)
    // function getStakedTimestamps(
    //     address _user
    // ) public view returns (uint256[] memory) {
    //     uint256[] storage timestamps;
    //     uint256 _tokensLength = stakers[_user].tokenIds.length;
    //     for(uint256 i = 0; i < _tokensLength; i++) {
    //         timestamps.push(stakers[_user].tokenIds[i]);
    //     }
    //     return timestamps;
    // }

    function getStakerAddresses() public view returns (address[] memory) {
        return stakersAddresses;
    }

    function setStakeMaximum(uint256 _stakeMaximum) public onlyOwner {
        stakeMaximum = _stakeMaximum;
    }

    function migrateData() public onlyOwner {
        address[] memory _stakerAddresses = getStakerAddresses();
        uint256 _stakerAddressesLength = _stakerAddresses.length;
        for(uint256 i = 0; i < _stakerAddressesLength;) {
            Staker memory _staker = stakers[_stakerAddresses[i]];
            
            uint256 _tokenIdsLength = _staker.tokenIds.length;
            for(uint256 j = 0; j < _tokenIdsLength;) {
                tokenIdsToStaking[_staker.tokenIds[j]] = 
                    Staking(_stakerAddresses[i], _staker.placeholderTokenIds[j], _staker.timestamps[j]);
                unchecked { ++j; }
            }
            unchecked { ++i; }
        }
    }
}
