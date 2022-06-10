module Animation.Type where

import Control.Monad.Trans.Reader (ReaderT(..))
import Control.Monad.Trans.State.Strict (StateT(..), evalStateT)

type Animation env st a = ReaderT env (StateT st IO) a

data Object = Ball Int               -- ^ X position of the Ball
            | Base Int Int           -- ^ X position and length of the Base
            | Wall (Either Int Int)  -- ^ X position of Either Left or Right Wall
            | Brick                  -- ^ Position and life of a Brick
                    { brickPosition :: (Int, Int) 
                    , life :: Int 
                    }
        deriving Eq
    
data GameStatus = Paused
                | Playing
                | Auto
                | Stopped
                | Starting
                | LevelComplete
                | Restarting
                deriving Show

data UserInput  = MoveLeft
                | MoveRight
                | Pause
                | Stop
                | Start
                | RestAuto
                | LeftWall
                | RightWall
                | Undefined
                deriving Eq

runAnimation :: env -> st -> Animation env st a -> IO a
runAnimation env st action = evalStateT (runReaderT action env) st
