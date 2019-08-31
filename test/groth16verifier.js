const Groth16Verifier = artifacts.require("./Groth16Verifier.sol");
const Groth16VerifierTest = artifacts.require("./Groth16VerifierTest.sol");

const compiler = require("circom");
const snarkjs = require("snarkjs");
const path = require("path");
const groth = snarkjs.groth;
const bigInt = snarkjs.bigInt;

let groth16VerifierTest = null;


function linearize_vk_verifier(vk_verifier) {
  const result = Array(14+2*vk_verifier.IC.length);
  result[0] = vk_verifier.vk_alfa_1[0];
  result[1] = vk_verifier.vk_alfa_1[1];

  result[2] = vk_verifier.vk_beta_2[0][1];
  result[3] = vk_verifier.vk_beta_2[0][0];
  result[4] = vk_verifier.vk_beta_2[1][1];
  result[5] = vk_verifier.vk_beta_2[1][0];
  
  result[6] = vk_verifier.vk_gamma_2[0][1];
  result[7] = vk_verifier.vk_gamma_2[0][0];
  result[8] = vk_verifier.vk_gamma_2[1][1];
  result[9] = vk_verifier.vk_gamma_2[1][0];
  
  result[10] = vk_verifier.vk_delta_2[0][1];
  result[11] = vk_verifier.vk_delta_2[0][0];
  result[12] = vk_verifier.vk_delta_2[1][1];
  result[13] = vk_verifier.vk_delta_2[1][0];

  for(let i=0; i<vk_verifier.IC.length; i++) {
    result[14+2*i] = vk_verifier.IC[i][0];
    result[14+2*i+1] = vk_verifier.IC[i][1];
  }
  return result;
}

function linearize_proof(proof) {
  const result = Array(8);
  result[0] = proof.pi_a[0];
  result[1] = proof.pi_a[1];

  result[2] = proof.pi_b[0][1];
  result[3] = proof.pi_b[0][0];
  result[4] = proof.pi_b[1][1];
  result[5] = proof.pi_b[1][0];

  result[6] = proof.pi_c[0];
  result[7] = proof.pi_c[1];
  
  return result;
}


contract('Groth16VerifierTest', (accounts) => {
  beforeEach(async () => {
    //const groth16Verifier = await Groth16Verifier.new();
    //await Groth16VerifierTest.link(Groth16Verifier, groth16Verifier.address);
    groth16VerifierTest = await Groth16VerifierTest.new();
  });
  
  it("Should process signle proof", async () => {
    const cirDef = await compiler(path.join(__dirname, "circuits", "test.circom"));
    const circuit = new snarkjs.Circuit(cirDef);
    const {vk_proof, vk_verifier} = groth.setup(circuit);
    
    const witness = circuit.calculateWitness({x:bigInt(3), y:bigInt(27)});

    const {proof, publicSignals} = groth.genProof(vk_proof, witness);
    
    

    const res = await groth16VerifierTest.verify(publicSignals.map(x=>x.toString()),
      linearize_proof(proof).map(x=>x.toString()),
      linearize_vk_verifier(vk_verifier).map(x=>x.toString()));
    
    assert(res, "proof must be valid");
  });

  it("Should process multiple proofs", async () => {
    const cirDef = await compiler(path.join(__dirname, "circuits", "test.circom"));
    const circuit = new snarkjs.Circuit(cirDef);
    const {vk_proof, vk_verifier} = groth.setup(circuit);
    
    const witness = circuit.calculateWitness({x:bigInt(3), y:bigInt(27)});

    const {proof, publicSignals} = groth.genProof(vk_proof, witness);
    
    
    let sol_input = publicSignals.map(x=>x.toString());
    sol_input = [].concat(sol_input, sol_input/*, sol_input*/);

    let sol_proof = linearize_proof(proof).map(x=>x.toString());
    sol_proof = [].concat(sol_proof, sol_proof/*, sol_proof*/);

    const res = await groth16VerifierTest.verifyMany(sol_input,
      sol_proof,
      linearize_vk_verifier(vk_verifier).map(x=>x.toString()));
    
    assert(res, "proof must be valid");
  });

})