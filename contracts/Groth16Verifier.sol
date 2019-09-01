//
// Copyright 2017 Christian Reitwiessner
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
pragma solidity >=0.5.2;


library Groth16Verifier {
  uint constant q = 21888242871839275222246405745257275088696311157297823662689037894645226208583;
  uint constant r = 21888242871839275222246405745257275088548364400416034343698204186575808495617;

  struct G1Point {
    uint X;
    uint Y;
  }
  // Encoding of field elements is: X[0] * z + X[1]
  struct G2Point {
    uint[2] X;
    uint[2] Y;
  }

  /// @return the sum of two points of G1
  function addition(G1Point memory p1, G1Point memory p2) internal view returns (G1Point memory r) {
    uint[4] memory input;
    input[0] = p1.X;
    input[1] = p1.Y;
    input[2] = p2.X;
    input[3] = p2.Y;
    bool success;
    /* solium-disable-next-line */
    assembly {
      success := staticcall(sub(gas, 2000), 6, input, 0xc0, r, 0x60)
      // Use "invalid" to make gas estimation work
      switch success case 0 { invalid() }
    }
    require(success);
  }

  /// @return the product of a point on G1 and a scalar, i.e.
  /// p == p.scalar_mul(1) and p.addition(p) == p.scalar_mul(2) for all points p.
  function scalar_mul(G1Point memory p, uint s) internal view returns (G1Point) {
    if(s==0) return G1Point(0,0);
    if(s==1) return p;
    G1Point memory t;
    uint[3] memory input;
    input[0] = p.X;
    input[1] = p.Y;
    input[2] = s;
    bool success;
    /* solium-disable-next-line */
    assembly {
      success := staticcall(sub(gas, 2000), 7, input, 0x80, t, 0x60)
      // Use "invalid" to make gas estimation work
      switch success case 0 { invalid() }
    }
    require (success);
    return t;
  }



  // batch verifier using random oracle model for proofs with at least 1 public input
  function verifyMany(uint[] memory input, uint[] memory proof, uint[] memory vk) internal view returns(bool) {
    uint nsignals = (vk.length-16)/2;
    uint nproofs = proof.length/8;
    require((nsignals>0) && (nproofs > 0) && (input.length == nsignals*nproofs) && (proof.length == nproofs*8) && (vk.length == 16 + 2*nsignals));

    for(uint i=0; i<input.length; i++)
      require(input[i]<r);

    uint[] memory p_input = new uint[](6*(nproofs+3));
    uint[] memory multipliers = new uint[](nproofs);
    G1Point memory t;
    uint m;
    uint seed = uint(keccak256(abi.encodePacked(input, proof, vk)));


    multipliers[0] = 1;
    for(uint i = 1; i < nproofs; i++)
      multipliers[i] = uint(keccak256(abi.encodePacked(seed, i))) % r;
    
    m = 1; //multipliers[0];
    for (uint i = 1; i < nproofs; i++)
      m = addmod(m, multipliers[i], r);

    // alpha1 computation
    t = scalar_mul(G1Point(vk[0], vk[1]), m);  //vk.alfa1 == G1Point(vk[0], vk[1])
    p_input[nproofs*6] = t.X;
    p_input[nproofs*6+1] = q-t.Y;

    //vk_x computation
    t = scalar_mul(G1Point(vk[14], vk[15]), m);  //vk.IC[0] == G1Point(vk[14], vk[15])
    for(uint j = 0; j < nsignals; j++) {
      m = input[j]; //mulmod(multipliers[0], input[j], r);
      for(uint i = 1; i < nproofs; i++)
        m = addmod(m, mulmod(multipliers[i], input[j + i*nsignals], r), r);
      t = addition(t, scalar_mul(G1Point(vk[16+2*j], vk[17+2*j]), m));  //vk.IC[j + 1] == G1Point(vk[16+2*j], vk[17+2*j])
    }
    p_input[nproofs*6+6] = t.X;
    p_input[nproofs*6+7] = q-t.Y;

    //C computation
    t = G1Point(proof[6], proof[7]); //scalar_mul(G1Point(proof[6], proof[7]), multipliers[0]); //proof[0].C == G1Point(proof[6], proof[7])
    for(uint i = 1; i < nproofs; i++)
      t = addition(t, scalar_mul(G1Point(proof[8*i+6], proof[8*i+7]), multipliers[i]));  //proof[i].C == G1Point(proof[8*i+6], proof[8*i+7])
    p_input[nproofs*6+12] = t.X;
    p_input[nproofs*6+13] = q-t.Y;


    p_input[0] = proof[0];
    p_input[1] = proof[1];
    p_input[2] = proof[2];
    p_input[3] = proof[3];
    p_input[4] = proof[4];
    p_input[5] = proof[5];

    for(uint i = 1; i < nproofs; i++) {
      t = scalar_mul(G1Point(proof[8*i], proof[8*i+1]), multipliers[i]);
      p_input[i*6] = t.X;
      p_input[i*6+1] = t.Y;
      p_input[i*6+2] = proof[8*i+2];
      p_input[i*6+3] = proof[8*i+3];
      p_input[i*6+4] = proof[8*i+4];
      p_input[i*6+5] = proof[8*i+5];
    }

    p_input[nproofs*6+2] = vk[2];
    p_input[nproofs*6+3] = vk[3];
    p_input[nproofs*6+4] = vk[4];
    p_input[nproofs*6+5] = vk[5];


    p_input[nproofs*6+8] = vk[6];
    p_input[nproofs*6+9] = vk[7];
    p_input[nproofs*6+10] = vk[8];
    p_input[nproofs*6+11] = vk[9];


    p_input[nproofs*6+14] = vk[10];
    p_input[nproofs*6+15] = vk[11];
    p_input[nproofs*6+16] = vk[12];
    p_input[nproofs*6+17] = vk[13];


    uint[1] memory out;
    bool success;
    /* solium-disable-next-line */
    assembly {
      success := staticcall(sub(gas, 2000), 8, add(p_input, 0x20), mul(add(nproofs, 3), 192), out, 0x20)
      // Use "invalid" to make gas estimation work
      switch success case 0 { invalid() }
    }
    require(success);
    return out[0] != 0;

  }

  function verify(uint[] memory input, uint[] memory proof, uint[] memory vk) internal view returns (bool) {
    uint nsignals = (vk.length-16)/2;
    require((nsignals>0) && (input.length == nsignals) && (proof.length == 8) && (vk.length == 16 + 2*nsignals));

    for(uint i=0; i<input.length; i++)
      require(input[i]<r);


    uint[] memory p_input = new uint[](24);

    p_input[0] = proof[0];
    p_input[1] = q-(proof[1]%q);  //proof.A negation
    p_input[2] = proof[2];
    p_input[3] = proof[3];
    p_input[4] = proof[4];
    p_input[5] = proof[5];

    // alpha1 computation
    p_input[6] = vk[0];     //vk.alfa1 == G1Point(vk[0], vk[1])
    p_input[7] = vk[1];


    p_input[8] = vk[2];
    p_input[9] = vk[3];
    p_input[10] = vk[4];
    p_input[11] = vk[5];

    //vk_x computation
    G1Point memory t = G1Point(vk[14], vk[15]);  //vk.IC[0] == G1Point(vk[14], vk[15])
    for(uint j = 0; j < nsignals; j++)
      t = addition(t, scalar_mul(G1Point(vk[16+2*j], vk[17+2*j]), input[j]));  //vk.IC[j + 1] == G1Point(vk[16+2*j], vk[17+2*j])

    p_input[12] = t.X;
    p_input[13] = t.Y;

    p_input[14] = vk[6];
    p_input[15] = vk[7];
    p_input[16] = vk[8];
    p_input[17] = vk[9];

    //C computation
    p_input[18] = proof[6];   //proof.C == G1Point(proof[6], proof[7])
    p_input[19] = proof[7];

    p_input[20] = vk[10];
    p_input[21] = vk[11];
    p_input[22] = vk[12];
    p_input[23] = vk[13];


    uint[1] memory out;
    bool success;
    // solium-disable-next-line 
    assembly {
      success := staticcall(sub(gas, 2000), 8, add(p_input, 0x20), 768, out, 0x20)
      // Use "invalid" to make gas estimation work
      switch success case 0 { invalid() }
    }

    require(success);
    return out[0] != 0;
  }

}
