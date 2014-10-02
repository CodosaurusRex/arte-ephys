module System.Arte.Decode.Graphics where

------------------------------------------------------------------------------
import           Control.Applicative
import           Control.Concurrent.STM
import           Control.Lens
import qualified Data.CircularList                as CL
import qualified Data.List                        as L
import qualified Data.Map.Strict                  as Map
import qualified Data.Vector                      as V
import qualified Graphics.Gloss.Data.Color        as Color
import           Graphics.Gloss.Interface.IO.Game
------------------------------------------------------------------------------
import           Data.Map.KDMap
import           Data.Ephys.EphysDefs
import           Data.Ephys.GlossPictures
import           System.Arte.Decode.Types
import           System.Arte.Decode.Config
import           System.Arte.Decode.Histogram


------------------------------------------------------------------------------
drawDrawOptionsState :: DecoderState -> Picture
drawDrawOptionsState ds =
  let filledCol = ds^.trodeInd
      filledRow = ds^.clustInd
      drawCol :: Int -> [TrodeDrawOption] -> Picture
      drawCol cInd col = pictures $
                         map (drawDot cInd col) [0..length col - 1]
      drawDot        = \cInd c rInd ->
        translate (fromIntegral cInd) (fromIntegral rInd) $
        if filledCol `mod` nOpts     == cInd &&
           filledRow `mod` length c == rInd :: Bool
        then color blue $ Circle 0.5 :: Picture
        else color red  $ ThickCircle 0.1 0.4 :: Picture
      nOpts          = length optsList
      optsList       = ds^.trodeDrawOpt
  in  pictures $ zipWith drawCol [0..nOpts-1] optsList





treeScale :: Float
treeScale = 2e6

treeTranslate :: (Float,Float)
treeTranslate = (-300,-300)


------------------------------------------------------------------------------
screenToTree :: (Float, Float) -> (Float, Float)
screenToTree (x,y) =
  ((x- fst treeTranslate)/treeScale, (y- snd treeTranslate)/treeScale)


------------------------------------------------------------------------------
treeToScreen :: (Float,Float) -> (Float, Float)
treeToScreen (x,y) =
  (x * treeScale + fst treeTranslate, y * treeScale + snd treeTranslate)


------------------------------------------------------------------------------
drawClusterlessPoint
  :: XChan -> YChan -> Double -> (ClusterlessPoint, MostRecentTime) -> Picture
drawClusterlessPoint (XChan x) (YChan y) tNow (cP,t) =
  translate (r2 $ pointD cP (Depth x)) (r2 $ pointD cP (Depth y)) $
  Pictures [ color (pointColor tNow t) $
             circleSolid (1e-6 + log (realToFrac $ pointW cP) / treeScale)
           , circle (1e-6 + log (r2 $ pointW cP) / treeScale)
           ]

pointAtSize
  :: XChan -> YChan -> ClusterlessPoint -> Double -> Picture
pointAtSize (XChan x) (YChan y) cP s =
  translate (r2 $ pointD cP (Depth x)) (r2 $ pointD cP (Depth y)) $
  circleSolid (r2 s)

------------------------------------------------------------------------------
drawTree
  :: XChan -> YChan -> Double -> KDMap ClusterlessPoint MostRecentTime -> Picture
drawTree xC yC tNow =
  Pictures . map (drawClusterlessPoint xC yC tNow) . toList


------------------------------------------------------------------------------
pointColor :: Double -> MostRecentTime -> Color.Color
pointColor tNow (MostRecentTime t) = Color.makeColor r g b 1
  where e tau = exp (-1 * (max dt 0) / tau)
        dt = (r2 tNow) - (r2 t)
        r  = e 0.2
        g  = e 1
        b  = e 20


------------------------------------------------------------------------------
drawHistogram :: (Float,Float) -> Histogram Double -> Picture
drawHistogram (sizeX,sizeY) h = Pictures [
  translate (-sizeX/2) 0 $ scale xScale yScale $ unscaledBars,
  translate (-sizeX/2) (-20) . scale 0.1 0.1            $ Text report
  ]
  where
    cnt     = V.sum $ h^.counts :: Int
    mean    = (/fI cnt) . V.sum $ V.zipWith (*) (realToFrac <$> h^.counts) (realToFrac <$> h^.bins)
    report  = unwords ["Mean: ", showWithUnit mean
                      ," Max:", showWithUnit tMax
                      ," Cnt:", showWithUnit (fI cnt)]
    nBins   = V.length $ h^.counts
    inds    = V.generate nBins id :: V.Vector Int
    drawBar :: Int -> Int -> Picture
    tMax = let nonEmptyBins = V.filter ((>0) . fst) $ V.zip (h^.counts) (h^.bins)
           in  case V.length nonEmptyBins of
             0 -> 0
             _ -> snd $ V.last nonEmptyBins
    drawBar i c = translate (fI i+0.5) ((log $fI c)/2) $
                  rectangleSolid 1 (log $ fI c)
    unscaledBars =
      Pictures $
      V.toList (V.zipWith drawBar inds (h^.counts))
      
    xScale = sizeX / fI nBins
    yScale = sizeY / (log $ fI . V.maximum $ h^.counts)


fI :: Int -> Float
fI = fromIntegral

showWithUnit :: (RealFrac a, Show a) => a -> String
showWithUnit x
  | x > 1000 = (pad3 . show $ floor (x/1000)) ++ "kSec"
  | x > 1    = (pad3 . show $ floor x)        ++ "sec"
  | x > 1e-3 = (pad3 . show $ floor (x*1000)) ++ "ms"
  | x > 1e-6 = (pad3 . show $ floor (x*1e6))  ++ "us"
  | x > 1e-9 = (pad3 . show $ floor (x*1e9))  ++ "ns"
  | otherwise = show x
  where pad3 s = L.replicate (length s - 3) ' ' ++ s
