using Avalonia.Controls;
using Avalonia.Controls.Shapes;
using Avalonia.Input;
using Avalonia.Interactivity;
using Avalonia.Media;
using System;
using System.Collections.Generic;
using System.Linq;

namespace TicTacToe.Views
{
    public partial class MainWindow : Window
    {
        private const int BoardSize = 10;
        private const double CellSize = 60;
        
        private GameLogic gameLogic;
        
        public MainWindow()
        {
            InitializeComponent();
            gameLogic = new GameLogic();
            DrawBoard();
            UpdateUI();
        }

        private void DrawBoard()
        {
            GameCanvas.Children.Clear();
            
            // Рисуем сетку 10x10
            for (int i = 0; i <= BoardSize; i++)
            {
                // Вертикальные линии
                var vLine = new Line
                {
                    StartPoint = new Avalonia.Point(i * CellSize, 0),
                    EndPoint = new Avalonia.Point(i * CellSize, BoardSize * CellSize),
                    Stroke = Brushes.Black,
                    StrokeThickness = 1
                };
                GameCanvas.Children.Add(vLine);
                
                // Горизонтальные линии
                var hLine = new Line
                {
                    StartPoint = new Avalonia.Point(0, i * CellSize),
                    EndPoint = new Avalonia.Point(BoardSize * CellSize, i * CellSize),
                    Stroke = Brushes.Black,
                    StrokeThickness = 1
                };
                GameCanvas.Children.Add(hLine);
            }
            
            // Рисуем X и O
            for (int row = 0; row < BoardSize; row++)
            {
                for (int col = 0; col < BoardSize; col++)
                {
                    int cell = gameLogic.GetCell(row, col);
                    if (cell == 1)
                    {
                        DrawX(row, col);
                    }
                    else if (cell == 2)
                    {
                        DrawO(row, col);
                    }
                }
            }
        }

        private void DrawX(int row, int col)
        {
            double margin = 10;
            double x = col * CellSize + margin;
            double y = row * CellSize + margin;
            double size = CellSize - 2 * margin;
            
            // Диагональ \
            var line1 = new Line
            {
                StartPoint = new Avalonia.Point(x, y),
                EndPoint = new Avalonia.Point(x + size, y + size),
                Stroke = Brushes.Blue,
                StrokeThickness = 3
            };
            Canvas.SetLeft(line1, 0);
            Canvas.SetTop(line1, 0);
            GameCanvas.Children.Add(line1);
            
            // Диагональ /
            var line2 = new Line
            {
                StartPoint = new Avalonia.Point(x + size, y),
                EndPoint = new Avalonia.Point(x, y + size),
                Stroke = Brushes.Blue,
                StrokeThickness = 3
            };
            Canvas.SetLeft(line2, 0);
            Canvas.SetTop(line2, 0);
            GameCanvas.Children.Add(line2);
        }

        private void DrawO(int row, int col)
        {
            double margin = 10;
            double x = col * CellSize + margin;
            double y = row * CellSize + margin;
            double size = CellSize - 2 * margin;
            
            var ellipse = new Ellipse
            {
                Width = size,
                Height = size,
                Stroke = Brushes.Red,
                StrokeThickness = 3,
                Fill = Brushes.Transparent
            };
            Canvas.SetLeft(ellipse, x);
            Canvas.SetTop(ellipse, y);
            GameCanvas.Children.Add(ellipse);
        }

        private void DrawWinningLine(List<(int, int)> winningCells)
        {
            if (winningCells.Count == 0) return;
            
            var firstCell = winningCells.First();
            var lastCell = winningCells.Last();
            
            double x1 = firstCell.Item2 * CellSize + CellSize / 2;
            double y1 = firstCell.Item1 * CellSize + CellSize / 2;
            double x2 = lastCell.Item2 * CellSize + CellSize / 2;
            double y2 = lastCell.Item1 * CellSize + CellSize / 2;
            
            var winLine = new Line
            {
                StartPoint = new Avalonia.Point(x1, y1),
                EndPoint = new Avalonia.Point(x2, y2),
                Stroke = Brushes.Green,
                StrokeThickness = 5
            };
            Canvas.SetLeft(winLine, 0);
            Canvas.SetTop(winLine, 0);
            GameCanvas.Children.Add(winLine);
        }

        private void OnCanvasClick(object? sender, PointerPressedEventArgs e)
        {
            if (gameLogic.GameOver) return;
            
            var point = e.GetPosition(GameCanvas);
            int col = (int)(point.X / CellSize);
            int row = (int)(point.Y / CellSize);
            
            if (row < 0 || row >= BoardSize || col < 0 || col >= BoardSize)
                return;
            
            if (gameLogic.MakeMove(row, col))
            {
                DrawBoard();
                CheckGameEnd();
                
                if (!gameLogic.GameOver)
                {
                    gameLogic.SwitchPlayer();
                    UpdateUI();
                }
            }
        }

        private async void CheckGameEnd()
        {
            var (hasWinner, winner, cells) = gameLogic.CheckWin();
            
            if (hasWinner)
            {
                DrawWinningLine(cells);
                gameLogic.SetGameOver();
                gameLogic.UpdateScore(winner);
                UpdateUI();
                
                string playerName = winner == 1 ? "Игрок 1 (X)" : "Игрок 2 (O)";
                await ShowMessageBox("Победа!", $"{playerName} победил!");
            }
            else if (gameLogic.CheckDraw())
            {
                gameLogic.SetGameOver();
                await ShowMessageBox("Ничья!", "Игра закончилась вничью!");
            }
        }

        private async System.Threading.Tasks.Task ShowMessageBox(string title, string message)
        {
            var messageBox = new Window
            {
                Title = title,
                Width = 300,
                Height = 150,
                WindowStartupLocation = WindowStartupLocation.CenterOwner,
                CanResize = false
            };
            
            var panel = new StackPanel
            {
                Margin = new Avalonia.Thickness(20),
                Spacing = 20
            };
            
            panel.Children.Add(new TextBlock
            {
                Text = message,
                FontSize = 16,
                TextWrapping = Avalonia.Media.TextWrapping.Wrap,
                HorizontalAlignment = Avalonia.Layout.HorizontalAlignment.Center
            });
            
            var okButton = new Button
            {
                Content = "OK",
                Width = 100,
                Height = 35,
                HorizontalAlignment = Avalonia.Layout.HorizontalAlignment.Center
            };
            okButton.Click += (s, e) => messageBox.Close();
            panel.Children.Add(okButton);
            
            messageBox.Content = panel;
            await messageBox.ShowDialog(this);
        }

        private void UpdateUI()
        {
            Player1ScoreLabel.Text = $"Игрок 1 (X): {gameLogic.Player1Score}";
            Player2ScoreLabel.Text = $"Игрок 2 (O): {gameLogic.Player2Score}";
            
            if (!gameLogic.GameOver)
            {
                string currentPlayerName = gameLogic.CurrentPlayer == 1 ? "Игрок 1 (X)" : "Игрок 2 (O)";
                CurrentPlayerLabel.Text = $"Ход: {currentPlayerName}";
            }
            else
            {
                CurrentPlayerLabel.Text = "Игра окончена";
            }
        }

        private void OnNewGame(object? sender, RoutedEventArgs e)
        {
            gameLogic.ResetGame();
            DrawBoard();
            UpdateUI();
        }

        private void OnResetScore(object? sender, RoutedEventArgs e)
        {
            gameLogic.ResetScore();
            gameLogic.ResetGame();
            DrawBoard();
            UpdateUI();
        }
    }
}
