import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

class SudokuScreen extends StatefulWidget {
  const SudokuScreen({super.key});

  @override
  State<SudokuScreen> createState() => _SudokuScreenState();
}

class _SudokuScreenState extends State<SudokuScreen> {
  final Random random = Random();

  late List<List<int>> board;
  late List<List<int>> solution;
  late List<List<bool>> fixed;
  late List<List<bool>> wrong;

  Timer? timer;

  int elapsedSeconds = 0;
  int lives = 3;
  int puzzleNumber = 1;

  bool gameStarted = false;
  bool mistakesEnabled = true;

  String difficulty = 'Easy';

  @override
  void initState() {
    super.initState();
    createEmptyBoard();
  }

  void createEmptyBoard() {
    board = List.generate(9, (_) => List.filled(9, 0));

    solution = List.generate(9, (_) => List.filled(9, 0));

    fixed = List.generate(9, (_) => List.filled(9, true));

    wrong = List.generate(9, (_) => List.filled(9, false));
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void startTimer() {
    timer?.cancel();

    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !gameStarted) return;

      setState(() {
        elapsedSeconds++;
      });
    });
  }

  void stopTimer() {
    timer?.cancel();
    timer = null;
  }

  String get formattedTime {
    final minutes = elapsedSeconds ~/ 60;
    final seconds = elapsedSeconds % 60;

    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  void startGame() {
    generatePuzzle();

    setState(() {
      gameStarted = true;
      puzzleNumber = 1;
      elapsedSeconds = 0;
      lives = mistakesEnabled ? 3 : 0;
    });

    startTimer();
  }

  void generatePuzzle() {
    solution = List.generate(9, (_) => List.filled(9, 0));

    fillBoard(solution);

    board = solution.map((row) => List<int>.from(row)).toList();

    fixed = List.generate(9, (_) => List.filled(9, true));

    wrong = List.generate(9, (_) => List.filled(9, false));

    int emptyCells;

    if (difficulty == 'Easy') {
      emptyCells = 38;
    } else if (difficulty == 'Medium') {
      emptyCells = 48;
    } else {
      emptyCells = 55;
    }

    int removed = 0;

    while (removed < emptyCells) {
      final row = random.nextInt(9);
      final col = random.nextInt(9);

      if (board[row][col] != 0) {
        board[row][col] = 0;
        fixed[row][col] = false;
        removed++;
      }
    }
  }

  bool fillBoard(List<List<int>> grid) {
    for (int row = 0; row < 9; row++) {
      for (int col = 0; col < 9; col++) {
        if (grid[row][col] == 0) {
          final numbers = List.generate(9, (index) => index + 1);

          numbers.shuffle(random);

          for (final number in numbers) {
            if (isSafe(grid, row, col, number)) {
              grid[row][col] = number;

              if (fillBoard(grid)) {
                return true;
              }

              grid[row][col] = 0;
            }
          }

          return false;
        }
      }
    }

    return true;
  }

  bool isSafe(List<List<int>> grid, int row, int col, int number) {
    // Row
    for (int c = 0; c < 9; c++) {
      if (grid[row][c] == number) {
        return false;
      }
    }

    // Column
    for (int r = 0; r < 9; r++) {
      if (grid[r][col] == number) {
        return false;
      }
    }

    // 3x3 box
    final startRow = (row ~/ 3) * 3;
    final startCol = (col ~/ 3) * 3;

    for (int r = startRow; r < startRow + 3; r++) {
      for (int c = startCol; c < startCol + 3; c++) {
        if (grid[r][c] == number) {
          return false;
        }
      }
    }

    return true;
  }

  void onCellTap(int row, int col) {
    if (!gameStarted) return;
    if (fixed[row][col]) return;

    showNumberPicker(row, col);
  }

  void showNumberPicker(int row, int col) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Choose a number',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 15),

                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (int number = 1; number <= 9; number++)
                      SizedBox(
                        width: 48,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            enterNumber(row, col, number);
                          },
                          child: Text(
                            '$number',
                            style: const TextStyle(fontSize: 18),
                          ),
                        ),
                      ),

                    // CLEAR
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            board[row][col] = 0;
                            wrong[row][col] = false;
                          });

                          Navigator.pop(context);
                        },
                        child: const Text('X', style: TextStyle(fontSize: 17)),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  void enterNumber(int row, int col, int number) {
    if (fixed[row][col]) return;

    // Do not deduct another life for the exact
    // same wrong answer in the same cell.
    if (wrong[row][col] && board[row][col] == number) {
      return;
    }

    setState(() {
      board[row][col] = number;

      if (number == solution[row][col]) {
        wrong[row][col] = false;
      } else {
        wrong[row][col] = true;

        if (mistakesEnabled) {
          lives--;
        }
      }
    });

    if (mistakesEnabled && lives <= 0) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          showGameOver();
        }
      });

      return;
    }

    checkPuzzleCompletion();
  }

  void checkPuzzleCompletion() {
    if (!gameStarted) return;

    for (int row = 0; row < 9; row++) {
      for (int col = 0; col < 9; col++) {
        if (board[row][col] == 0) {
          return;
        }

        if (board[row][col] != solution[row][col]) {
          return;
        }
      }
    }

    completePuzzle();
  }

  void completePuzzle() {
    stopTimer();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            '🎉 Sudoku Complete!',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(
            'You solved the $difficulty puzzle!\n\n'
            'Time: $formattedTime',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);

                setState(() {
                  puzzleNumber++;
                  elapsedSeconds = 0;
                  lives = mistakesEnabled ? 3 : 0;
                });

                generatePuzzle();
                startTimer();
              },
              child: const Text('NEXT PUZZLE'),
            ),
          ],
        );
      },
    );
  }

  void showGameOver() {
    stopTimer();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            '💀 GAME OVER',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(
            'You lost all 3 lives.\n\n'
            'Time: $formattedTime',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                restartGame();
              },
              child: const Text('RESTART'),
            ),
          ],
        );
      },
    );
  }

  void restartGame() {
    stopTimer();

    setState(() {
      gameStarted = false;
      elapsedSeconds = 0;
      puzzleNumber = 1;
      lives = mistakesEnabled ? 3 : 0;
    });
  }

  void resetPuzzle() {
    if (!gameStarted) return;

    setState(() {
      for (int row = 0; row < 9; row++) {
        for (int col = 0; col < 9; col++) {
          if (!fixed[row][col]) {
            board[row][col] = 0;
            wrong[row][col] = false;
          }
        }
      }

      if (mistakesEnabled) {
        lives = 3;
      }
    });
  }

  Widget difficultyButton(String value) {
    final selected = difficulty == value;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            difficulty = value;
          });
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? Colors.blue : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? Colors.blue : Colors.grey.shade300,
              width: 2,
            ),
          ),
          child: Center(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: selected ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildMistakesSwitch() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Mistakes',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),

        Switch(
          value: mistakesEnabled,
          onChanged: (value) {
            setState(() {
              mistakesEnabled = value;
              lives = value ? 3 : 0;
            });
          },
        ),

        Text(
          mistakesEnabled ? 'ON' : 'OFF',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: mistakesEnabled ? Colors.green : Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget buildLives() {
    if (!mistakesEnabled) {
      return const SizedBox.shrink();
    }

    return Container(
      width: 50,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'LIVES',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 6),

          for (int i = 0; i < 3; i++)
            Icon(
              Icons.favorite,
              size: 25,
              color: i < lives ? Colors.red : Colors.grey.shade400,
            ),
        ],
      ),
    );
  }

  Widget buildSudokuGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = min(constraints.maxWidth, 360.0);

        return SizedBox(
          width: size,
          height: size,
          child: GridView.builder(
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 9,
            ),
            itemCount: 81,
            itemBuilder: (context, index) {
              final row = index ~/ 9;
              final col = index % 9;

              return GestureDetector(
                onTap: () {
                  onCellTap(row, col);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: fixed[row][col]
                        ? Colors.grey.shade300
                        : wrong[row][col]
                        ? Colors.red.shade100
                        : Colors.white,
                    border: Border(
                      top: BorderSide(
                        color: Colors.black,
                        width: row % 3 == 0 ? 2 : 0.5,
                      ),
                      left: BorderSide(
                        color: Colors.black,
                        width: col % 3 == 0 ? 2 : 0.5,
                      ),
                      right: BorderSide(
                        color: Colors.black,
                        width: col == 8 ? 2 : 0.5,
                      ),
                      bottom: BorderSide(
                        color: Colors.black,
                        width: row == 8 ? 2 : 0.5,
                      ),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      board[row][col] == 0 ? '' : '${board[row][col]}',
                      style: TextStyle(
                        fontSize: size / 17,
                        fontWeight: FontWeight.bold,
                        color: fixed[row][col]
                            ? Colors.black
                            : wrong[row][col]
                            ? Colors.red
                            : Colors.blue,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget buildStartScreen() {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(25),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.grid_3x3, size: 85, color: Colors.blue),

              const SizedBox(height: 15),

              const Text(
                'SUDOKU',
                style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 8),

              const Text(
                'Choose your difficulty',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),

              const SizedBox(height: 25),

              Row(
                children: [
                  difficultyButton('Easy'),
                  difficultyButton('Medium'),
                  difficultyButton('Hard'),
                ],
              ),

              const SizedBox(height: 25),

              buildMistakesSwitch(),

              const SizedBox(height: 25),

              SizedBox(
                width: 230,
                height: 55,
                child: ElevatedButton(
                  onPressed: startGame,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'START GAME',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildGameScreen() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            // DIFFICULTY + TIMER
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  difficulty,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                Row(
                  children: [
                    const Icon(Icons.timer_outlined, size: 22),
                    const SizedBox(width: 5),
                    Text(
                      formattedTime,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 4),

            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Puzzle $puzzleNumber',
                style: const TextStyle(fontSize: 15, color: Colors.grey),
              ),
            ),

            const SizedBox(height: 10),

            // GRID + LIVES
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Flexible(child: buildSudokuGrid()),

                const SizedBox(width: 8),

                buildLives(),
              ],
            ),

            const SizedBox(height: 15),

            buildMistakesSwitch(),

            const SizedBox(height: 10),

            OutlinedButton.icon(
              onPressed: resetPuzzle,
              icon: const Icon(Icons.refresh),
              label: const Text('RESET PUZZLE'),
            ),

            const SizedBox(height: 5),

            TextButton(
              onPressed: () {
                stopTimer();

                setState(() {
                  gameStarted = false;
                  elapsedSeconds = 0;
                });
              },
              child: const Text('BACK TO START'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sudoku'), centerTitle: true),
      body: gameStarted ? buildGameScreen() : buildStartScreen(),
    );
  }
}
