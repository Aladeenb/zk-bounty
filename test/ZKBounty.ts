import { expect, use } from "chai";
import { ethers } from "hardhat";
import { Contract, Signer, BigNumberish } from "ethers";

describe("ZKBounty", function () {
  let zkBounty: Contract;
  let owner: Signer;
  let addr1: Signer;
  let addr2: Signer;

  beforeEach(async function () {
    [owner, addr1, addr2] = await ethers.getSigners();
  
    // Deploy the ZKBounty contract
    const ZKBountyFactory = await ethers.getContractFactory("ZKBounty");
    zkBounty = await ZKBountyFactory.deploy();
    // No need to call `await zkBounty.deployed()` as `deploy()` returns the deployed instance
  });

  describe("submitBounty", function () {
    it("should allow a user to submit a bounty", async function () {
      const bountyType: number = 0;  // BountyType.ApiKey
      const reward: BigNumberish = ethers.parseEther("1.0");
      const bountyHash: string = "testHash";
  
      await expect(zkBounty.submitBounty(bountyType, reward, bountyHash))
          .to.emit(zkBounty, "BountySubmitted")
          .withArgs(await zkBounty.getKeyAtIndex(0), await owner.getAddress(), bountyType, reward);
  
      const bountyId = await zkBounty.getKeyAtIndex(0);
      const bounty = await zkBounty.get(bountyId);
  
      expect(bounty.submitter).to.equal(await owner.getAddress());
      expect(bounty.bountyType).to.equal(bountyType);
      expect(bounty.reward).to.equal(reward);
      expect(bounty.bountyHash).to.equal(bountyHash);
  });  
  });

  describe("submitReport", function () {
    it("should allow a user to submit a report for an existing bounty", async function () {
        const bountyType: number = 0;  // BountyType.ApiKey
        const reward: BigNumberish = ethers.parseEther("1.0");
        const bountyHash: string = "testHash";

        await zkBounty.submitBounty(bountyType, reward, bountyHash);
        const bountyId = await zkBounty.getKeyAtIndex(0);
        const reportHash: string = "reportHash";

        await zkBounty.submitReport(bountyId, reportHash);

        const report = await zkBounty.reports(bountyId);
        expect(report.worker).to.equal(await owner.getAddress());
        expect(report.reportHash).to.equal(reportHash);
        expect(report.isSubmitted).to.be.true;
    });

    it("should fail if the bounty does not exist", async function () {
        const nonExistentBountyId =  "0x0";
        const reportHash: string = "reportHash";

        await expect(zkBounty.submitReport(nonExistentBountyId, reportHash))
            .to.be.revertedWith("Bounty does not exist");
    });
});


describe("approveReport", function () {
  it("should allow the submitter to approve a report", async function () {
      const bountyType: number = 0;  // BountyType.ApiKey
      const reward: BigNumberish = ethers.parseEther("1.0");
      const bountyHash: string = "testHash";

      await zkBounty.submitBounty(bountyType, reward, bountyHash);
      const bountyId = await zkBounty.getKeyAtIndex(0);
      const reportHash: string = "reportHash";

      await zkBounty.submitReport(bountyId, reportHash);

      const initialBalance = await ethers.provider.getBalance(await owner.getAddress());

      await expect(zkBounty.approveReport(bountyId))
          .to.emit(zkBounty, "ReportApproved")
          .withArgs(bountyId);

      // Check if the reward has been transferred
      const balanceAfter = await ethers.provider.getBalance(await owner.getAddress());
      expect(balanceAfter).to.be.gt(initialBalance);
  });

  it("should fail if the caller is not the submitter", async function () {
      const bountyType: number = 0;  // BountyType.ApiKey
      const reward: BigNumberish = ethers.parseEther("1.0");
      const bountyHash: string = "testHash";

      await zkBounty.submitBounty(bountyType, reward, bountyHash);
      const bountyId = await zkBounty.getKeyAtIndex(0);
      const reportHash: string = "reportHash";

      await zkBounty.submitReport(bountyId, reportHash);

      await expect(zkBounty.connect(addr1).approveReport(bountyId))
          .to.be.revertedWith("Not the submitter");
  });
});

describe("withdrawUnapprovedBounty", function () {
  it("should allow the submitter to withdraw an unapproved bounty", async function () {
      const bountyType: number = 0;  // BountyType.ApiKey
      const reward: BigNumberish = ethers.parseEther("1.0");
      const bountyHash: string = "testHash";

      await zkBounty.submitBounty(bountyType, reward, bountyHash);
      const bountyId = await zkBounty.getKeyAtIndex(0);
      await zkBounty.depositReward({ value: reward });

      const initialBalance = await ethers.provider.getBalance(await owner.getAddress());

      await expect(zkBounty.withdrawUnapprovedBounty(bountyId))
          .to.emit(zkBounty, "BountyWithdrawn")
          .withArgs(bountyId);

      // Check if the reward has been transferred
      const balanceAfter = await ethers.provider.getBalance(await owner.getAddress());
      expect(balanceAfter).to.be.gt(initialBalance);
  });

  it("should fail if the bounty is already approved or the caller is not the submitter", async function () {
      const bountyType: number = 0;  // BountyType.ApiKey
      const reward: BigNumberish = ethers.parseEther("1.0");
      const bountyHash: string = "testHash";

      await zkBounty.submitBounty(bountyType, reward, bountyHash);
      const bountyId = await zkBounty.getKeyAtIndex(0);
      await zkBounty.depositReward({ value: reward });

      // Submit a report and approve it
      const reportHash: string = "reportHash";
      await zkBounty.submitReport(bountyId, reportHash);
      await zkBounty.approveReport(bountyId);

      await expect(zkBounty.withdrawUnapprovedBounty(bountyId))
          .to.be.revertedWith("Bounty is already approved");

      await expect(zkBounty.connect(addr1).withdrawUnapprovedBounty(bountyId))
          .to.be.revertedWith("Not the submitter");
  });
});


  describe("getBountyType", function () {
    it("should return the correct BountyType", async function () {
      const bountyType = await zkBounty.getBountyType();
      expect(bountyType).to.equal(0);  // BountyType.ApiKey
    });
  });

  describe("Fallback Function", function () {
    it("should accept Ether", async function () {
        await expect(() => owner.sendTransaction({ to: zkBounty.address, value: ethers.parseEther("1.0") }))
            .to.changeEtherBalance(zkBounty, ethers.parseEther("1.0"));
          });
    });
});
