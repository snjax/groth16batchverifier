pragma solidity >=0.5.2;
import "../Groth16Verifier.sol";


contract Groth16VerifierTest {
  using Groth16Verifier for Groth16Verifier.G1Point;
  using Groth16Verifier for Groth16Verifier.G2Point;
  
  function verify(uint[] memory input, uint[] memory proof, uint[] memory vk) public view returns (bool) {
    return Groth16Verifier.verify(input, proof, vk);
  }

  function verifyMany(uint[] memory input, uint[] memory proof, uint[] memory vk) public view returns(bool) {
    return Groth16Verifier.verifyMany(input, proof, vk);
  }
}