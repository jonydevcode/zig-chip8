# CHIP-8 Emulator in Zig

![No LLM Generation](https://img.shields.io/badge/LLM%20generation-none-brightgreen)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue)](./LICENSE)

A CHIP-8 emulator (actually interpreter) written in Zig. Uses SDL3 GPU API for display and inputs.

![IBM logo](screenshots/01-ibmlogo.png)

## AI Use Disclosure

The current contents of this repository were written without LLM/AI code generation. All AI usage in any form by contributors must be disclosed.

## Getting Started

### Dependencies

- Zig 0.16
- [castholm/SDL](https://github.com/castholm/SDL)

### Installing

```bash
zig build
```

### Executing program

```bash
zig build run -- rom_file.ch8
```

## Acknowledgments

- [zig](https://codeberg.org/ziglang/zig)
- [castholm/SDL](https://github.com/castholm/SDL)
- [Guide to making a CHIP-8 emulator](https://tobiasvl.github.io/blog/write-a-chip-8-emulator/)
- [Timendus/chip8-test-suit](https://github.com/Timendus/chip8-test-suite)

## License

Distributed under the MIT License. See [LICENSE](./LICENSE) for more information.

## Screenshots

![Timendus CHIP-8 test suite - flags test](screenshots/02-timendus-flags.png)
![Timendus CHIP-8 test suite - keypad test](screenshots/03-timendus-keypad.png)
![Stars by Sergey Naydenov, 2010](screenshots/04-stars.png)
![Octojam 7 Title by JohnEarnest](screenshots/05-octojam7.png)
