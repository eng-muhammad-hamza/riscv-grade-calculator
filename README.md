# RISC-V Grade Calculator

![Architecture](https://img.shields.io/badge/Architecture-RISC--V%20(RV64)-blue?style=flat-square)
![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)
![Environment](https://img.shields.io/badge/Environment-Linux%20%2F%20QEMU-orange?style=flat-square)
![Assembly](https://img.shields.io/badge/Language-Assembly-lightgrey?style=flat-square)

A RISC-V 64-bit assembly program that parses student records from a text file, computes weighted aggregate scores, assigns letter grades, writes student results to an output file, and prints class statistics to standard output.

The implementation relies on direct Linux raw syscalls without the C standard library (`-nostdlib`).

## Grade Weight Distribution

| Component | Weight (%) | Maximum Marks |
| :--- | :--- | :--- |
| Quiz 1 | 5% | 10 |
| Quiz 2 | 5% | 10 |
| Assignment 1 | 10% | 100 |
| Assignment 2 | 10% | 100 |
| Midterm Exam | 30% | 50 |
| Final Exam | 40% | 100 |

## File Specifications

### Input (`input.txt`)

Each line in `input.txt` represents a single student record with whitespace-separated values:

```text
<First_Name> <Last_Name> <Roll_No> <Quiz1> <Quiz2> <Assignment1> <Assignment2> <Midterm> <Final>
```

Example:

```text
Muhammad Hamza BSSE23001 9 7 90 100 45 90
Fatima Noorulain BSSE23003 4 5 100 100 44 92
```

### Output (`output.txt`)

Processed records are written to `output.txt` containing the student name, roll number, weighted total score, and assigned letter grade:

```text
<First_Name> <Last_Name> <Roll_No> <Weighted_Total> <Grade>
```

Example:

```text
Muhammad Hamza BSSE23001 90 A
Fatima Noorulain BSSE23003 88 A
```

### Console Output

Running the executable outputs summary statistics directly to stdout:

```text
Failed Students:
<First_Name> <Last_Name> <Roll_No>
...
Total No of Students: <Count>
Average Marks of Class: <Average>
```

## Prerequisites

- `gcc-riscv64-linux-gnu` (GNU cross-assembler and linker for RISC-V 64)
- `qemu-user` (`qemu-riscv64` emulator)

On Debian/Ubuntu-based systems:

```bash
sudo apt update
sudo apt install gcc-riscv64-linux-gnu qemu-user
```

## Build and Execution

1. Assemble and link without standard libraries:

   ```bash
   riscv64-linux-gnu-gcc -nostdlib -static -o program program.s
   ```

2. Run the program using QEMU:

   ```bash
   qemu-riscv64 ./program
   ```

3. Review the generated `output.txt` and terminal summary.

## License

This project is licensed under the [MIT License](LICENSE).
