module Animation.Env where

import Animation.Type (UserInput(..))

data Env =
    Env
        { title       :: String     -- ^ Title of the Game
        , fps         :: Int        -- ^ Frames per second 
        , size        :: (Int, Int) -- ^ Size of the game
        , velocity    :: Int        -- ^ Speed of the ball
        , baselength  :: Int        -- ^ Length of the base (%)
        , bricklength :: Int        -- ^ Length of the bricks (%)
        , lifes       :: Int        -- ^ Life of the bricks
        , wallsHeight :: Int        -- ^ Height of the Walls (%)
        , wallsGap    :: Int        -- ^ Separation of the Walls (%)
        }

defaultEnv :: Env
defaultEnv =
    Env { title       = "BRICK BREAKER VIDEOGAME"
        , fps         = 20
        , size        = (75, 22)
        , velocity    = 1
        , baselength  = 15 * fst (size defaultEnv) `div` 100
        , bricklength = 5  * fst (size defaultEnv) `div` 100    
        , lifes       = 2
        , wallsHeight = 60 * (snd (size defaultEnv) - 2) `div` 100
        , wallsGap    = 20 *  fst (size defaultEnv)      `div` 100
        }