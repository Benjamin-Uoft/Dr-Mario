# Dr. Mario in Assembly

## Overview
This project is an implementation of the classic **Dr. Mario** game, developed entirely in **assembly language**. It captures the core gameplay mechanics of the original game, including virus elimination, pill-matching, and increasing difficulty across levels.

Players can enjoy a retro gaming experience while observing the low-level intricacies of game development in assembly.

---

## Features
- **Classic Gameplay Mechanics**: Match pills with viruses to clear the board.
- **Multiple Levels**: Progress through increasingly challenging levels.
- **Score System**: Tracks your points based on cleared viruses and combos.
- **Assembly-Powered Graphics**: The game visuals, including the pill bottle, pills, and viruses, are rendered using bitmap graphics.
- **Keyboard Controls**: Move and rotate pills using keyboard inputs via memory-mapped I/O.

---

## Controls
- **Arrow Keys**: Move the pill left or right.
- **Down Arrow**: Accelerate the pill's fall.
- **Spacebar**: Rotate the pill clockwise.
- **Enter**: Start the game or move to the next level.

---

## How to Play
1. **Objective**: Match pills of the same color with viruses in vertical or horizontal rows of 4 or more to clear them.
2. **Viruses**: Each level starts with a set number of viruses scattered in the pill bottle.
3. **Level Progression**: Eliminate all viruses to move to the next level.
4. **Game Over**: The game ends if the pill bottle fills up and no more pills can be placed.

---

## Technical Details
- **Platform**: Designed for execution on MARS (MIPS Assembler and Runtime Simulator).
- **Input Handling**: Uses memory-mapped I/O to capture keyboard inputs.
- **Rendering**: Pills, viruses, and the bottle are drawn using bitmap manipulation.
- **Levels**: The number and arrangement of viruses increase with each level, simulating the difficulty progression of the original Dr. Mario.
- **Collision Detection**: Implemented to handle pill stacking and alignment.

---

## Setup and Execution
### Prerequisites
- **MARS Simulator**: Download and install the MARS MIPS simulator from [http://courses.missouristate.edu/kenvollmar/mars/](http://courses.missouristate.edu/kenvollmar/mars/).

### Running the Game
1. Clone or download the repository.
   ```bash
   git clone https://github.com/your-username/dr-mario-assembly.git
   ```
2. Open the `.asm` file in the MARS simulator.
3. Assemble the code by clicking on **Assemble**.
4. Run the program by clicking on **Go**.

---

## Files
- `dr_mario.asm`: Main assembly code for the game.
- `README.md`: Documentation.
- `assets/`: Bitmap files or data for rendering graphics.

---

## Future Improvements
- Add background music and sound effects.
- Include a 2-player mode.
- Implement save and load functionality for game states.
- Add additional difficulty settings.

---

## Credits
- **Developer**: [Your Name]
- Inspired by the original **Dr. Mario** game by Nintendo.

---

## License
This project is licensed under the MIT License. See the `LICENSE` file for details.

---

Enjoy the game and happy debugging!
