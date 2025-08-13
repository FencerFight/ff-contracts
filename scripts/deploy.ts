import { ethers, upgrades  } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploy from:", deployer.address);

  const GovernanceFactory = await ethers.getContractFactory("PlatformGovernance");
  const governance = await upgrades.deployProxy(GovernanceFactory, [["0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"]], { kind: "uups" });
  await governance.waitForDeployment();
  const governanceAddr = await governance.getAddress();
  console.log("PlatformGovernance:", governanceAddr);

  const FencerFactory = await ethers.getContractFactory("Fencer");
  const fencer = await upgrades.deployProxy(FencerFactory, [governanceAddr], { kind: "uups" });
  await fencer.waitForDeployment();
  const fencerAddr = await fencer.getAddress();
  console.log("Fencer:", fencerAddr);

  const TournamentFactory = await ethers.getContractFactory("Tournament");
  const tournament = await upgrades.deployProxy(TournamentFactory, [governanceAddr, fencerAddr], { kind: "uups" });
  await tournament.waitForDeployment();
  const tournamentAddr = await tournament.getAddress();
  console.log("Tournament:", tournamentAddr);

  const SBTFactory = await ethers.getContractFactory("AchievementSBT");
  const sbt = await upgrades.deployProxy(SBTFactory, [governanceAddr, tournamentAddr], { kind: "uups" });
  await sbt.waitForDeployment();
  const sbtAddr = await sbt.getAddress();
  console.log("AchievementSBT:", sbtAddr);
  await tournament.setAchievementSBT(sbtAddr);
  await governance.initAddress(fencerAddr, tournamentAddr);

  const nominations = [
    [0, 16, [], [], "", 0, 0], // nameId, max, participants, winners, badgeURI, weaponId, gender
    [1, 20, [], [], "", 0, 0]
  ];
  const packed = ethers.AbiCoder.defaultAbiCoder().encode(
    ['tuple(uint8 nameId, uint8 max, address[] participants, address[] winners, string badgeURI, uint8 weaponId, uint8 gender)[]'],
    [nominations]
  );

  await tournament.createTournament(
    'Кубок Ростова',
    'eyJkZXNjcmlwdGlvbiI6ImZkZmRmZGZkZmRmZGRnZGdmZ2ZnZmdmaGgiLCJpbWFnZSI6Imh0dHBzOi8vYXZhdGFycy5tZHMueWFuZGV4Lm5ldC9pP2lkPWUyZjMwY2FjM2RmMTk1N2Q2OTA1ZGM1YjdmMDk2N2I5X2wtNTg3NDkxOS1pbWFnZXMtdGh1bWJzJm49MTMiLCJzb2NpYWxMaW5rcyI6WyJodHRwczovL3ZrLmNvbS9mZW5jZXJmaWdodCJdfQ==', // Cid
    0,              // cityId
    0,              // countryId
    1718640000,     // date
    3600,           // startTime (секунды)
    packed
  );

  await fencer.addCity("Ростов")
  await fencer.addCountry("Россия")
  await tournament.addJudge("0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266", 0)
  await tournament.addJudge("0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266", 0)
  await fencer.addClub("HEMA TEAM")
  await fencer.addUser("Артём", 0, 0, 0, 0)
  await fencer.addWeaponRating(0, 0)
  await tournament.registerParticipant(0, 0)

  console.log("Data initialized via Fencer ✅");
}

main().then(() => process.exit(0)).catch(console.error);