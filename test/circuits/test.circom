template test() {
  signal input x;
  signal input y;
  signal z;
  z <== x*x;
  y === z*x;
}

component main = test();