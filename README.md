## ML Accelerator Dataflows

This repository houses reproducible code and testbenches to compare an output
stationary dataflow and a weight stationary dataflow in an ML accelerator. It
accompanies a paper at the [Canadian Undergraduate Conference on AI](https://cucai.ca/).

![The two different architectures](./preview/Overview.png)

## Instructions
- If you don't want to install any tools but want to play with the hardware modules, try copy-pasting Verilog code in the `src` folder into [EDAPlayground](https://www.edaplayground.com/).
- If you want to run the hardware modules locally, install [Icarus Verilog](https://steveicarus.github.io/iverilog/usage/installation.html).
- If you want to run testbenches in the `test` folder, run `pip3 install -r test/requirements.txt` to install Cocotb.
- If you want to run the scheduler notebooks in the `scheduler` folder, run `pip3 install -r scheduler/requirements.txt` to install Jupyter and other dependencies.