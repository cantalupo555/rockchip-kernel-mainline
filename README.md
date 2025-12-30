# rockchip-kernel-mainline

This repository contains scripts and configurations to automate the building of multiple Armbian images, initially focusing on Rockchip RK3588 based boards.

## Overview

The main script, `multi_armbian_builder.sh`, orchestrates the build process, allowing the generation of images for different combinations of:

*   Boards
*   Releases
*   Desktop Environments (for Desktop images)
*   Server Images (without a graphical environment)

It utilizes the [official Armbian build framework](https://github.com/armbian/build).

## Prerequisites

- Ubuntu 24.04
- Git
- Armbian Build Framework dependencies (see official documentation)

## Configuration

1. Clone this repository:
   ```bash
   git clone https://github.com/cantalupo555/rockchip-kernel-mainline.git
   cd rockchip-kernel-mainline/
   ```
2. Adjust parameters in `multi_armbian_builder.sh` if necessary.

## Usage

1. Make the script executable:
   ```bash
   chmod +x multi_armbian_builder.sh
   ```
2. Run the script:
   ```bash
   ./multi_armbian_builder.sh
   ```

   The script provides an **interactive menu** that allows you to:

   1. **Select build type**: Desktop, Server, or Both
   2. **Select boards** (multi-select): orangepi5, orangepi5-plus, rock-5a, rock-5b, rock-5b-plus
   3. **Select releases** (multi-select):
      - Desktop: `noble` (Ubuntu 24.04), `questing` (Ubuntu 25.10)
      - Server: `noble` (Ubuntu 24.04), `questing` (Ubuntu 25.10), `trixie` (Debian 13)
   4. **Review configuration** and confirm before building

   The script will:
*   Check for/clone the `build/` directory.
*   Copy custom configuration files and scripts into the `build/` directory structure.
*   Present interactive menus to select build options.
*   Start the selected build loops.
*   Print logs and the final summary to the console.

## Output

*   Successfully built images will be found inside the `build/output/images/` directory.
*   The build summary will be displayed at the end of the script execution.

---
---
---

## Downloads

## Desktop Images

| Board | Release | Codename | Kernel Version | Download Link |
|-------|---------------|---------|----------------|----------------|
| orangepi5 | Ubuntu 24.04 | noble | 6.17-rc1 | [Download](https://disk.yandex.com/d/JYUslzGiLuDWNA) |
| orangepi5 | Ubuntu 25.04 | plucky | 6.17-rc1 | [Download](https://disk.yandex.com/d/6EG5_e9ig9gP4A) |
| orangepi5-plus | Ubuntu 24.04 | noble | 6.17-rc1 | [Download](https://disk.yandex.com/d/WzBfE6WFjd4mdg) |
| orangepi5-plus | Ubuntu 25.04 | plucky | 6.17-rc1 | [Download](https://disk.yandex.com/d/Bp6T2r3bKkPPDA) |
| rock-5a | Ubuntu 24.04 | noble | 6.17-rc1 | [Download](https://disk.yandex.com/d/sGeGHX7cxEe0FQ) |
| rock-5a | Ubuntu 25.04 | plucky | 6.17-rc1 | [Download](https://disk.yandex.com/d/pgUxbkRvAfJgXQ) |
| rock-5b | Ubuntu 24.04 | noble | 6.17-rc1 | [Download](https://disk.yandex.com/d/_wpHOJPGvWl9JQ) |
| rock-5b | Ubuntu 25.04 | plucky | 6.17-rc1 | [Download](https://disk.yandex.com/d/kNgpYSGMOCNYtA) |
| rock-5b-plus | Ubuntu 24.04 | noble | 6.17-rc1 | [Download](https://disk.yandex.com/d/db__W8VapXXeWQ) |
| rock-5b-plus | Ubuntu 25.04 | plucky | 6.17-rc1 | [Download](https://disk.yandex.com/d/lsGsT1xfjOi9tA) |

## Server Images

| Board | Release | Codename | Kernel Version | Download Link |
|-------|---------------|---------|----------------|----------------|
| orangepi5 | Ubuntu 24.04 | noble | 6.17-rc1 | Coming Soon |
| orangepi5 | Debian 13 | trixie | 6.17-rc1 | Coming Soon |
| orangepi5-plus | Ubuntu 24.04 | noble | 6.17-rc1 | Coming Soon |
| orangepi5-plus | Debian 13 | trixie | 6.17-rc1 | Coming Soon |
| rock-5a | Ubuntu 24.04 | noble | 6.17-rc1 | Coming Soon |
| rock-5a | Debian 13 | trixie | 6.17-rc1 | Coming Soon |
| rock-5b | Ubuntu 24.04 | noble | 6.17-rc1 | Coming Soon |
| rock-5b | Debian 13 | trixie | 6.17-rc1 | Coming Soon |
| rock-5b-plus | Ubuntu 24.04 | noble | 6.17-rc1 | Coming Soon |
| rock-5b-plus | Debian 13 | trixie | 6.17-rc1 | Coming Soon |
