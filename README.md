# CHIP-8 Emulator in Zig

![No LLM Generation](https://img.shields.io/badge/LLM%20generation-none-brightgreen)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue)](./LICENSE)

A CHIP-8 emulator (actually interpreter) written in Zig. Uses SDL3 for display and inputs.

## AI Use Disclosure

The current contents of this repository were written without LLM/AI code generation. All AI usage in any form by contributors must be disclosed.

## Screenshots

![IBM logo](screenshots/01-ibmlogo.png)

## Getting Started

### Dependencies

- Zig 0.16
- [allyourcodebase/SDL3](https://github.com/allyourcodebase/SDL3)

### Installing

```bash
zig build
```

### Executing program

```bash
zig build run
```

## Acknowledgments

- [zig](https://codeberg.org/ziglang/zig)
- [allyourcodebase/SDL3](https://github.com/allyourcodebase/SDL3)
- [Guide to making a CHIP-8 emulator](https://tobiasvl.github.io/blog/write-a-chip-8-emulator/)

## License

Distributed under the MIT License. See [LICENSE](./LICENSE) for more information.
