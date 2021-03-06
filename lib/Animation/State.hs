module Animation.State where

import Control.Monad.Trans.State.Strict (get, put)
import Control.Monad.Trans.Reader (ask)
import Control.Monad.Trans.Class (lift)
import System.IO (hReady, stdin, hSetEcho, hSetBuffering, BufferMode(NoBuffering))
import Data.Char (toUpper, toLower)

import Animation.Env (Env(..))
import Animation.Type ( Animation
                      , GameStatus(..)
                      , UserInput(..)
                      , Object(..)
                      )

data Direction
    = Positive
    | Negative
    | Neutral

directionFromInt :: Int -> Direction
directionFromInt 0 = Neutral
directionFromInt 1 = Positive
directionFromInt 2 = Negative
directionFromInt _ = error "Boooooo....."

directionToMultiplier :: Direction -> Int
directionToMultiplier Positive =  1
directionToMultiplier Negative = -1
directionToMultiplier Neutral  =  0

data St =
    St
        { position     :: (Int, Int)                -- ^ Position of the ball
        , direction    :: (Direction, Direction)    -- ^ Direction of the ball in N^2
        , bXPosition   :: Int                       -- ^ Position X of the base
        , bricks       :: [Object]                  -- ^ List of Bricks
        , walls        :: Maybe Object              -- ^ Definition of Walls
        , points       :: Int                       -- ^ Score (Every time a Brick is hit)
        , userInputs   :: [UserInput]               -- ^ List of User's Input (This list is able to manage more than one input per frame)
        , status       :: GameStatus                -- ^ Status of the Game
        }

{-|
  Allocation of the list of reduced positions in the game. A reduced position is a 'x' value divided by the brick length.
  Positions in this function are a list of 'x positions'. This means that given width = 50 then positions 49, 50, 51, 52,... correspond to points (49,0), (50,0), (1,1), (2,1),...
-}

bricksInPlace :: Int -> [Int] -> Int -> Int -> [Object]
bricksInPlace width positions life bricklength = map (\x -> Brick (findPosition (bricklength*x) width 0) life) positions
           where findPosition x width level = if x < width then (x,level) else findPosition (x - width) width (level + 1)

-- | Default state

defaultSt :: St
defaultSt = St (0, 0) (Neutral, Neutral) 0 [] Nothing 0 [] Stopped

-- | Management of the User Input

getUserInput :: IO (Maybe UserInput)
getUserInput = go Nothing
        where go a = do
                hSetBuffering stdin NoBuffering 
                hSetEcho stdin False
                waiting   <- hReady stdin
                if not waiting then return Nothing
                else do
                      hSetBuffering stdin NoBuffering
                      key  <- getChar
                      more <- hReady stdin
                      (if more then go else return) $ Just (stringToUserInput key)
                      where stringToUserInput x | x `isChar` 'a' = MoveLeft  
                                                | x `isChar` 'd' = MoveRight 
                                                | x `isChar` 'p' = Pause     
                                                | x `isChar` 'q' = Stop      
                                                | x `isChar` 's' = Start     
                                                | x `isChar` 'r' = RestAuto   
                                                | x `isChar` ' ' = RestAuto   
                                                | x `isChar` 'j' = LeftWall  
                                                | x `isChar` 'l' = RightWall 
                                                | otherwise      = Undefined 
                            isChar c1 c2 = c1 == toLower c2 || c1 == toUpper c2 

next :: Animation Env St ()
next = do
    env    <- ask
    prevSt <- lift get
    input  <- lift $ lift $ getUserInput
    lift ( put ( nextInternal env input prevSt ) )


-- | Management of next state according to GameStatus, UserInput and Previous State

nextInternal :: Env -> Maybe UserInput -> St -> St
nextInternal (Env _ _ (width, height) velocity baselength bricklength _ wallHeight wallsGap) 
             userInput
             prevSt@(St (prevX, prevY) (prevXDir, prevYDir) prevBXPos prevBricks prevWalls prevPoints readInputs prevStatus)
             =
   
    case prevStatus of
        Paused        -> case userInput of 
                              Just Pause    -> prevSt {status = Playing}
                              Just Stop     -> prevSt {status = Stopped}
                              Just RestAuto -> prevSt {status = Auto   }
                              _             -> prevSt
        Stopped       -> case userInput of 
                              Just RestAuto -> prevSt {status = Restarting}
                              _             -> prevSt
        Starting      -> case userInput of 
                              Just RestAuto -> prevSt {status = Restarting }
                              Just Start    -> prevSt {status = Playing    }     
                              _             -> prevSt { position   = (newBXPos + div baselength 2, prevY)
                                                      , bXPosition = newBXPos 
                                                      , walls      = newWalls
                                                      , userInputs = newInputs }
        LevelComplete -> case userInput of 
                              Just RestAuto -> prevSt {status = Restarting}
                              _             -> prevSt
        Playing       -> if prevBricks /= [] then
                            case userInput of 
                                Just Stop      -> prevSt {status = Stopped}
                                Just Pause     -> prevSt {status = Paused }
                                Just RestAuto  -> prevSt {status = Auto   }
                                _  -> St 
                                           { position   = (newX, newY)
                                           , direction  = (newXDir, newYDir)
                                           , bXPosition = newBXPos
                                           , bricks     = newBricks
                                           , walls      = newWalls
                                           , points     = newPoints
                                           , userInputs = newInputs
                                           , status     = newStatus
                                           }
                         else prevSt {status = LevelComplete }
        Auto          -> if prevBricks /= [] then
                            case userInput of 
                                Just Stop  -> prevSt {status = Stopped    }
                                Just Pause -> prevSt {status = Paused     }
                                _  -> St 
                                           { position   = (newX, newY)
                                           , direction  = (newXDir, newYDir)
                                           , bXPosition = newBXPos
                                           , bricks     = newBricks
                                           , walls      = newWalls
                                           , points     = newPoints
                                           , userInputs = newInputs
                                           , status     = newStatus
                                           }
                         else prevSt {status = LevelComplete }

    where
 
 -- New_Unbounded tells us which would be the position of the ball if there is no bounding
   
    newXUnbounded          = prevX + directionToMultiplier prevXDir * velocity
    newYUnbounded          = prevY + directionToMultiplier prevYDir * velocity

 -- Position control of the base limited by the width - Repeating Input interrupts the action
    
    newBXPos = case prevStatus of 
                    Auto -> restricted (prevX - div baselength 2)
                    _    -> baseDecisionTree userInput readInputs (moveBase (-2)) (moveBase ( 2)) prevBXPos 

    moveBase i = let newBxPos = prevBXPos + i in restricted newBxPos

    restricted position = if position + baselength >= width
                          then width - baselength
                          else if position <= 0
                               then 0
                               else position

 -- Detection of collision with the base
    
    baseCollision          = newY >= height - 2 && newBXPos <= newX && newX <= newBXPos + baselength

    baseCornerCollision    = newY >= height - 2 
                          && not baseCollision 
                          && ( newBXPos              <= newX + newX - prevX 
                          &&   newBXPos + baselength >= newX + newX - prevX )

 -- Auxiliary functions to consider the length of a brick, not just their position
 -- completePositions returns a list of occupied positions given a list of Bricks
    
    addPositions (u,v) brl = zip [u .. (u + brl - 1)] $ take brl $ repeat v
    completePositions      = foldl (\x y -> x ++ addPositions (brickPosition y) bricklength) []
    
 -- Identification of the coordinate that will be impacted according to ball direction for three 
 -- different cases: Collision with top or botton (brickCollisionY), collision with one side (brickCollisionX)   
 -- or collision with a corner (cornerCollision)

    targetX                = ( newX + directionToMultiplier prevXDir, newY)
    targetY                = ( newX, newY + directionToMultiplier prevYDir)
    cornerTarget           = ( newX + directionToMultiplier prevXDir
                             , newY + directionToMultiplier prevYDir )

    impossibleXCollision   = elem (bouncedTargetX, snd targetY) $ completePositions prevBricks
    impossibleYCollision   = elem (fst targetX, bouncedTargetY) $ completePositions prevBricks

    bouncedTargetX         = newX + directionToMultiplier prevXDir * velocity * (-1)
    bouncedTargetY         = newY + directionToMultiplier prevYDir * velocity * (-1)

    brickCollisionX        = elem targetX      $ completePositions prevBricks
    brickCollisionY        = elem targetY      $ completePositions prevBricks
    cornerCollision        = elem cornerTarget $ completePositions prevBricks

    xBrickBounce           = brickCollisionX && not impossibleXCollision
    yBrickBounce           = brickCollisionY && not impossibleYCollision
    bounceBack             = cornerCollision && not xBrickBounce && not yBrickBounce
                          || ( brickCollisionX && impossibleXCollision )
                          || ( brickCollisionY && impossibleYCollision )
                          || ( (newXUnbounded <= 0 || newXUnbounded >= width) && impossibleXCollision )
                          || ( newYUnbounded <= 0 && impossibleYCollision )

    wallCollisionX         = case prevWalls of
                                 Just wall -> wallCollision wall targetX
                                 Nothing -> False
    wallCollisionY         = case prevWalls of
                                 Just wall -> wallCollision wall targetY
                                 Nothing -> False
    wallCornerCollision    = case prevWalls of
                                 Just wall -> wallCollision wall cornerTarget && not wallCollisionX && not wallCollisionY
                                 Nothing -> False
    
    wallCollision (Wall w) target = let condition x = x == fst target 
                                                   && snd target >= div (height - 2 - wallHeight) 2 
                                                   && snd target <= div (height - 2 + wallHeight) 2
                                     in case w of (Left  xPos) -> condition xPos 
                                                  (Right xPos) -> condition xPos

 -- Update positions and directions for next state
    
    newX =
        case prevXDir of
            Neutral  ->     newXUnbounded
            Positive -> min newXUnbounded width
            Negative -> max newXUnbounded 0
    newY =
        case prevYDir of
            Neutral  ->     newYUnbounded
            Positive -> min newYUnbounded height
            Negative -> max newYUnbounded 0
    newXDir =
        case prevXDir of
            Neutral  -> Neutral
            Positive -> if newXUnbounded >= width || wallCollisionX || wallCornerCollision || xBrickBounce || bounceBack || baseCornerCollision
                        then Negative
                        else Positive
            Negative -> if newXUnbounded <= 0     || wallCollisionX || wallCornerCollision || xBrickBounce || bounceBack || baseCornerCollision
                        then Positive
                        else Negative
    newYDir =
        case prevYDir of
            Neutral  -> Neutral
            Positive -> if brickCollisionY        || wallCollisionY || wallCornerCollision || yBrickBounce || bounceBack || baseCornerCollision || baseCollision
                        then Negative
                        else Positive
            Negative -> if newYUnbounded <= 0     || wallCollisionY || wallCornerCollision || yBrickBounce || bounceBack 
                        then Positive
                        else Negative
    
 -- Update status in case the player is unable to bounce back the ball
    
    newStatus = if newY == height then Stopped else prevStatus
 
 -- Update the score in case of any brick collision 
    
    newPoints = (+) prevPoints $ fromEnum $ xBrickBounce || yBrickBounce || bounceBack

 -- Identification of the block that will be hit

    targetBricks = let identify target = filter (\u -> snd target == snd (brickPosition u) 
                                       && fst target -  fst (brickPosition u) < bricklength 
                                       && fst target -  fst (brickPosition u) >= 0          ) prevBricks
                    in if xBrickBounce && yBrickBounce then identify targetX ++ identify targetY
                  else if xBrickBounce                 then identify targetX
                  else if                 yBrickBounce then identify targetY
                  else if bounceBack                   then if ( cornerCollision && not xBrickBounce && not yBrickBounce )
                                                            then identify cornerTarget
                                                            else if impossibleXCollision
                                                                 then identify targetX ++ identify (bouncedTargetX, snd targetY)
                                                                 else identify targetY ++ identify (fst targetX, bouncedTargetY)
                                                                 else []

 -- Update the bricks state according to collisions. Brick disappears if life = 0
    
    newBricks = foldl (flip changeBricks) prevBricks targetBricks

 -- Update the life of the bricks
    
    changeBricks x bricks = let brickTail  = filter ((/=) (brickPosition x) . brickPosition) bricks
                                brickHurt  = Brick (brickPosition x) (life x - 1)
                             in if life x > 0 then brickHurt : brickTail else brickTail

 -- Update the state of the walls. Repeating Input interrupts the action

    newWalls = if elem RightWall readInputs then
                  case userInput of
                       Just RightWall -> Nothing
                       Just LeftWall  -> Just $ Wall $ Left  wallsGap
                       _              -> Just $ Wall $ Right (width - wallsGap)
          else if elem LeftWall  readInputs then
                  case userInput of
                       Just LeftWall  -> Nothing
                       Just RightWall -> Just $ Wall $ Right (width - wallsGap)
                       _              -> Just $ Wall $ Left  wallsGap
             else case userInput of
                       Just LeftWall  -> Just $ Wall $ Left  wallsGap
                       Just RightWall -> Just $ Wall $ Right (width - wallsGap)
                       _              -> Nothing

 -- Read & record the UserInputs - Repeating Input interrupts the action

    newInputs = let wallInputs = case newWalls of  
                     Just (Wall (Left _))  -> [LeftWall] 
                     Just (Wall (Right _)) -> [RightWall] 
                     _ -> []
                 in baseDecisionTree userInput readInputs (MoveLeft : wallInputs) (MoveRight : wallInputs) wallInputs
                           
 -- Decision helper function

    baseDecisionTree uInput rInput effect1 effect2 noEffect = case uInput of 
                                           Just MoveLeft  -> if not $ elem MoveRight rInput || elem MoveLeft  rInput then effect1 else noEffect
                                           Just MoveRight -> if not $ elem MoveLeft  rInput || elem MoveRight rInput then effect2 else noEffect
                                           _              -> if elem MoveLeft rInput && prevBXPos > 0 then effect1
                                                               else if elem MoveRight rInput && prevBXPos + baselength < width then effect2
                                                                 else noEffect