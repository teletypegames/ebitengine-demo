package main

import (
	"image/color"
	"log"
	"math"
	"time"

	"github.com/hajimehoshi/ebiten/v2"
	"github.com/hajimehoshi/ebiten/v2/text"
	"golang.org/x/image/font/basicfont"
)

const (
	screenW = 640
	screenH = 480
	scale   = 6.0
	spacing = 1
)

type Game struct {
	start time.Time
}

var palette = []color.RGBA{
	{0x1a, 0x1c, 0x2c, 0xff},
	{0x5d, 0x27, 0x5d, 0xff},
	{0xb1, 0x3e, 0x53, 0xff},
	{0xef, 0x7d, 0x57, 0xff},
	{0xff, 0xcd, 0x75, 0xff},
}

func (g *Game) Update() error { return nil }

func (g *Game) Draw(screen *ebiten.Image) {
	screen.Fill(color.Black)

	msg := "TELETYPE GAMES"
	t := float64(time.Since(g.start).Milliseconds()) / 400.0

	charW := int(7*scale) + spacing
	totalW := len(msg) * charW
	startX := (screenW - totalW) / 2
	baseY := screenH / 2

	for i, r := range msg {
		x := startX + i*charW
		y := baseY + int(math.Sin(t+float64(i)*0.4)*28)
		col := palette[(i+int(t*2))%len(palette)]

		draw := func(dx, dy int, c color.Color) {
			op := &ebiten.DrawImageOptions{}
			op.GeoM.Scale(scale, scale)
			op.GeoM.Translate(float64(x+dx), float64(y+dy))
			op.ColorScale.ScaleWithColor(c)
			text.DrawWithOptions(screen, string(r), basicfont.Face7x13, op)
		}

		draw(4, 4, color.RGBA{0, 0, 0, 180})
		draw(0, 0, col)
	}
}

func (g *Game) Layout(_, _ int) (int, int) {
	return screenW, screenH
}

func main() {
	ebiten.SetWindowSize(screenW, screenH)
	ebiten.SetWindowTitle("Teletype Games")

	game := &Game{start: time.Now()}
	if err := ebiten.RunGame(game); err != nil {
		log.Fatal(err)
	}
}