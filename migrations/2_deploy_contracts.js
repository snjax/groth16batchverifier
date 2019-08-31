const Groth16Verifier = artifacts.require('Groth16Verifier');
const Groth16VerifierTest = artifacts.require('Groth16VerifierTest');


module.exports = async function (deployer, network, accounts) {
//  await deployer.deploy(Groth16Verifier);
//  await deployer.link(Groth16Verifier, Groth16VerifierTest);
  await deployer.deploy(Groth16VerifierTest);
};
