pragma solidity >=0.6.12;

// import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
// import "@openzeppelin/contracts/access/Ownable.sol";

// contract BentoToken is ERC20("BentoToken", "BENTO"), Ownable {
contract BentoToken {
  // @notice EIP-20 token name
  string public name = "Bento Token";

  // @notice EIP-20 token symbol
  string public symbol = "BENTO";

  // @notice EIP-20 token decimal precision
  uint8 public constant decimals = 2;

  // @notice EIP-20 token total supply
  uint256 public totalSupply;

  // @notice EIP-20 token standard / version
  string public standard = "Bento Token v1.0";

  event Transfer(
    address indexed _from,
    address indexed _to,
    uint256 _value
  );

  event Approval(
    address indexed _owner,
    address indexed _spender,
    uint256 _value
  );

  mapping(address => uint256) public balanceOf;
  mapping(address => mapping(address => uint256)) public allowance;

  constructor(uint256 _initialSupply) public {
    balanceOf[msg.sender] = _initialSupply;
    totalSupply = _initialSupply;
  }

  function transfer(address _to, uint256 _value) public returns (bool success) {
    // Require stops gas usage if condition is not met
    require(balanceOf[msg.sender] >= _value);
    balanceOf[msg.sender] -= _value;
    balanceOf[_to] += _value;

    emit Transfer(msg.sender, _to, _value);

    return true;
  }

  function approve(address _spender, uint256 _value) public returns (bool success) {
    allowance[msg.sender][_spender] = _value;

    emit Approval(msg.sender, _spender, _value);

    return true;
  }

  function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
    require(_value <= balanceOf[_from]);
    require(_value <= allowance[_from][msg.sender]);

    balanceOf[_from] -= _value;
    balanceOf[_to] += _value;
    
    allowance[_from][msg.sender] -= _value;
    
    Transfer(_from, _to, _value);

    return true;
  }
}