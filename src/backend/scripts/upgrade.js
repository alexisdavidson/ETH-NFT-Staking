const { ethers, upgrades } = require("hardhat");
const fromWei = (num) => ethers.utils.formatEther(num);

async function main() {
  const [deployer] = await ethers.getSigners();
  let quirklingsNft, quirkiesNft, rewardNft, placeholderNft, nftStakerProxy;

  console.log("Deploying contracts with the account:", deployer.address);
  console.log(
    "Account balance:",
    fromWei(await deployer.getBalance()).toString()
  );

  // goerli
  // let teamWallet = "0x923129ECE79Ffb16B3cCb770474f6B672e68d8e0";
  // const quirklingsAddress = "0x3EF92D61970c721FA6ddB3AC4140333532C0a174"
  // const quirkiesAddress = "0x70DD3736354Ba9B02e3DF5f350235593777CC274"
  // const rewardNftAddress = "0x11c3B553D550A8406321e459b253630dbD017EE5"
  // const placeholderNftAddress = "0xeCbe81A64229ac0d6eb131b0465937Ec62a93eDA"
  // const stakingPeriod = 5 * 60; // 5 Minutes


  // mainnet
  let teamWallet = "0xab359600EB635C51D52Df927AaEA9534608c0d06";
  const quirklingsAddress = "0xDA60730E1feAa7D8321f62fFb069eDd869E57D02"
  const quirkiesAddress = "0x3903d4fFaAa700b62578a66e7a67Ba4cb67787f9"
  const rewardNftAddress = "0x2B33CD745211EB6F3c6EdF62BCd40fad0CA2Ff1e"
  const placeholderNftAddress = "0x175b3EBa3b1C2C366CCF164C178b182B9B716249"
  const stakingPeriod = 30 * 24 * 60 * 60; // 30 Days

  
  // change this to NFTStakerV2
  const NFTStaker = await ethers.getContractFactory("src/backend/contracts/NFTStakerV2.sol:NFTStakerV2");
  //goerli: 0xC4a49E76E3fc8ddd7DA58Efb1E8F2edD9eeFBDBb
  //mainnet: 0x1089901933DF7AF11009B91dB0fc5d74c1260643 :: V2:0x8cD75c53D4626D25beeD4DdCD3832Ed17b239923
  // create instance of old proxy address
  const oldStaker = await ethers.getContractAt(
    "NFTStaker",
    "0x1089901933DF7AF11009B91dB0fc5d74c1260643"
  );

  nftStakerProxy = await upgrades.upgradeProxy(
    oldStaker, // old proxy instance
    NFTStaker, // new contract instance
    {
      call: {
        fn: "initialize",
        args: [
          1,
          10,
          stakingPeriod,
          teamWallet,
          [quirklingsAddress, quirkiesAddress],
          placeholderNftAddress,
          rewardNftAddress,
        ],
      },
    }
  );
  await nftStakerProxy.deployed();

  console.log("Setter calls done");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
