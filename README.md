# 2 PLAYERS BRICK BREAKER VIDEOGAME

Delivered version of Brick Breaker videogame for Cardano Developer Program (EMURGO)

![example-gif](example.gif)

![GitHub last commit](https://img.shields.io/github/last-commit/gerardVM/brick-breaker)

## Installation

Clone this repository and build and run the Docker image

```bash
docker build -t bb-2p . && docker run --rm -it bb-2p
```

## Usage

Player 1's objective is to break all the bricks by avoiding the ball to touch the floor

Controls for player 1: 
- A - Left (Same key for Move and Stop) 
- D - Right (Same key for Move and Stop)
- SPACE - Auto Mode

Player 2's objective is to make it harder (or easier) to player 1 by enabling EITHER the Left Smart Wall or the Right Smart Wall

Controls for player 2: 
- J - Left Wall (Same key for Enable and Disable)
- L - Right Wall (Same key for Enable and Disable)

## Contributing

Pull requests are welcome

## License

[MIT](LICENSE.txt)
