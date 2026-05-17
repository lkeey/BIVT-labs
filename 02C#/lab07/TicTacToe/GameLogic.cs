using System;
using System.Collections.Generic;

namespace TicTacToe
{
    public class GameLogic
    {
        private const int BoardSize = 10;
        private const int WinLength = 5;
        
        private int[,] board;  // 0 = пусто, 1 = X (игрок 1), 2 = O (игрок 2)
        private int currentPlayer;
        private int player1Score;
        private int player2Score;
        private bool gameOver;

        public int CurrentPlayer => currentPlayer;
        public int Player1Score => player1Score;
        public int Player2Score => player2Score;
        public bool GameOver => gameOver;

        public GameLogic()
        {
            board = new int[BoardSize, BoardSize];
            currentPlayer = 1;
            player1Score = 0;
            player2Score = 0;
            gameOver = false;
        }

        public int GetCell(int row, int col)
        {
            if (row < 0 || row >= BoardSize || col < 0 || col >= BoardSize)
                return -1;
            return board[row, col];
        }

        public bool MakeMove(int row, int col)
        {
            if (gameOver || row < 0 || row >= BoardSize || col < 0 || col >= BoardSize)
                return false;

            if (board[row, col] != 0)
                return false;

            board[row, col] = currentPlayer;
            return true;
        }

        public void SwitchPlayer()
        {
            currentPlayer = currentPlayer == 1 ? 2 : 1;
        }

        public (bool hasWinner, int winner, List<(int, int)> winningCells) CheckWin()
        {
            // Проверка всех возможных выигрышных комбинаций
            for (int row = 0; row < BoardSize; row++)
            {
                for (int col = 0; col < BoardSize; col++)
                {
                    int player = board[row, col];
                    if (player == 0) continue;

                    // Проверка горизонтали (→)
                    if (col + WinLength <= BoardSize)
                    {
                        bool win = true;
                        for (int i = 1; i < WinLength; i++)
                        {
                            if (board[row, col + i] != player)
                            {
                                win = false;
                                break;
                            }
                        }
                        if (win)
                        {
                            var cells = new List<(int, int)>();
                            for (int i = 0; i < WinLength; i++)
                                cells.Add((row, col + i));
                            return (true, player, cells);
                        }
                    }

                    // Проверка вертикали (↓)
                    if (row + WinLength <= BoardSize)
                    {
                        bool win = true;
                        for (int i = 1; i < WinLength; i++)
                        {
                            if (board[row + i, col] != player)
                            {
                                win = false;
                                break;
                            }
                        }
                        if (win)
                        {
                            var cells = new List<(int, int)>();
                            for (int i = 0; i < WinLength; i++)
                                cells.Add((row + i, col));
                            return (true, player, cells);
                        }
                    }

                    // Проверка диагонали (\)
                    if (row + WinLength <= BoardSize && col + WinLength <= BoardSize)
                    {
                        bool win = true;
                        for (int i = 1; i < WinLength; i++)
                        {
                            if (board[row + i, col + i] != player)
                            {
                                win = false;
                                break;
                            }
                        }
                        if (win)
                        {
                            var cells = new List<(int, int)>();
                            for (int i = 0; i < WinLength; i++)
                                cells.Add((row + i, col + i));
                            return (true, player, cells);
                        }
                    }

                    // Проверка диагонали (/)
                    if (row + WinLength <= BoardSize && col - WinLength + 1 >= 0)
                    {
                        bool win = true;
                        for (int i = 1; i < WinLength; i++)
                        {
                            if (board[row + i, col - i] != player)
                            {
                                win = false;
                                break;
                            }
                        }
                        if (win)
                        {
                            var cells = new List<(int, int)>();
                            for (int i = 0; i < WinLength; i++)
                                cells.Add((row + i, col - i));
                            return (true, player, cells);
                        }
                    }
                }
            }

            return (false, 0, new List<(int, int)>());
        }

        public bool CheckDraw()
        {
            for (int row = 0; row < BoardSize; row++)
            {
                for (int col = 0; col < BoardSize; col++)
                {
                    if (board[row, col] == 0)
                        return false;
                }
            }
            return true;
        }

        public void SetGameOver()
        {
            gameOver = true;
        }

        public void UpdateScore(int winner)
        {
            if (winner == 1)
                player1Score++;
            else if (winner == 2)
                player2Score++;
        }

        public void ResetGame()
        {
            board = new int[BoardSize, BoardSize];
            currentPlayer = 1;
            gameOver = false;
        }

        public void ResetScore()
        {
            player1Score = 0;
            player2Score = 0;
        }
    }
}
