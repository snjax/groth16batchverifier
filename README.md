# groth16batchverifier

Batch verifier for zkSNARKs using random oracle model for proof batching.

```
\sum_i m_i (A, B) - ( (\sum_i m_i) \alpha, \beta ) - (\sum_j (\sum_i m_i input_i) IC_j, \gamma) - (\sum_i m_i C_i, \delta ) == 0,
```
where `m_i = hash(inputs, proof, vk, i)`.

See more information here: https://ethresear.ch/t/batching-of-zk-snark-proofs/5626
