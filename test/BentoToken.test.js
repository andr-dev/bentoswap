const { expectRevert } = require("@openzeppelin/test-helpers");
const BentoToken = artifacts.require("BentoToken");

contract("BentoToken", ([alice, bob, carol]) => {
  beforeEach(async () => {
    this.bento = await BentoToken.new({ from: alice });
  });

  it("should have correct name and symbol and decimal", async () => {
    const name = await this.bento.name();
    const symbol = await this.bento.symbol();
    const decimals = await this.bento.decimals();
    assert.equal(name.valueOf(), "BentoToken");
    assert.equal(symbol.valueOf(), "BENTO");
    assert.equal(decimals.valueOf(), "18");
  });

  it("should only allow owner to mint token", async () => {
    await this.bento.mint(alice, "100", { from: alice });
    await this.bento.mint(bob, "1000", { from: alice });
    await expectRevert(this.bento.mint(carol, "1000", { from: bob }), "Ownable: caller is not the owner");
    const totalSupply = await this.bento.totalSupply();
    const aliceBal = await this.bento.balanceOf(alice);
    const bobBal = await this.bento.balanceOf(bob);
    const carolBal = await this.bento.balanceOf(carol);
    assert.equal(totalSupply.valueOf(), "1100");
    assert.equal(aliceBal.valueOf(), "100");
    assert.equal(bobBal.valueOf(), "1000");
    assert.equal(carolBal.valueOf(), "0");
  });

  it("should supply token transfers properly", async () => {
    await this.bento.mint(alice, "100", { from: alice });
    await this.bento.mint(bob, "1000", { from: alice });
    await this.bento.transfer(carol, "10", { from: alice });
    await this.bento.transfer(carol, "100", { from: bob });
    const totalSupply = await this.bento.totalSupply();
    const aliceBal = await this.bento.balanceOf(alice);
    const bobBal = await this.bento.balanceOf(bob);
    const carolBal = await this.bento.balanceOf(carol);
    assert.equal(totalSupply.valueOf(), "1100");
    assert.equal(aliceBal.valueOf(), "90");
    assert.equal(bobBal.valueOf(), "900");
    assert.equal(carolBal.valueOf(), "110");
  });

  it("should fail if you try to do bad transfers", async () => {
    await this.bento.mint(alice, "100", { from: alice });
    await expectRevert(this.bento.transfer(carol, "110", { from: alice }), "ERC20: transfer amount exceeds balance");
    await expectRevert(this.bento.transfer(carol, "1", { from: bob }), "ERC20: transfer amount exceeds balance");
  });
});
