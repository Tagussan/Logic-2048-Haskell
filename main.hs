import Debug.SimpleReflect
import Data.List

data Val = Zero | NonZero deriving (Eq, Show)

data RelKind = Eq | Diff deriving (Eq, Show)
type MovFunc = (Expr, Expr, Expr, Expr) -> (Expr, Expr, Expr, Expr)
type Rel = (RelKind, (Int, Int))
type Rels = [Rel]
type Vals = [Val]
type PaddedValsSet = [Vals]
type PaddedVals = Vals
type InitCond = (Rels, Vals)
type Logic = (InitCond, MovFunc)

shiftRel :: Int -> Rel -> Rel
shiftRel offset (kind, (a, b)) = (kind, ((shift a), (shift b)))
  where shift x
          | x >= offset = x + 1
          | otherwise   = x

shiftVals :: Int -> Vals -> Vals
shiftVals offset vals = (take offset vals) ++ [Zero] ++ (drop offset vals)

type MergeLogic = (Vals, Rels, MovFunc)

relKindSeqs :: [[RelKind]]
relKindSeqs = [] : [p : x | x <- relKindSeqs, p <- [Diff, Eq]]

relSeqs :: [Rels]
relSeqs = map addRange relKindSeqs
  where addRange x = zipWith putRange [0 .. length x - 1] x
        putRange n x = (x, (n, n + 1))

initRels = takeWhile ((>=) 3 . length) relSeqs

movFuncFromAdjRels :: Rels -> MovFunc
movFuncFromAdjRels rels = merge rels id
  where merge [] _ = id
        merge ((Diff, _):[]) f = merge [] f . id
        merge ((Eq, (a, _)):[]) f = merge [] f . mergeFuncAt a
        merge ((Diff, _):y:ys) f = merge (y:ys) f . id
        merge ((Eq, (a, _)):(_, rng):ys) f = merge (map shiftRng ((Diff, rng):ys)) f . mergeFuncAt a
        shiftRng (k, (a, b)) = (k, (a - 1, b - 1))

mergeFuncAt :: Int -> MovFunc
mergeFuncAt p = \ (a, b, c, d) -> case p of
  0 -> (a + 1, c, d, 0)
  1 -> (a, b + 1, d, 0)
  2 -> (a, b, c + 1, 0)

shiftFuncAt :: Int -> MovFunc
shiftFuncAt p = \ (a, b, c, d) -> case p of
  0 -> (b, c, d, 0)
  1 -> (a, c, d, 0)
  2 -> (a, b, d, 0)


valsFromInitRels :: Rels -> Vals
valsFromInitRels rels = take (length rels + 1) $ repeat NonZero

initVals = map valsFromInitRels initRels
initLogics = map (\ rels -> ((rels, valsFromInitRels rels), movFuncFromAdjRels rels)) initRels

debugMovFunc :: MovFunc -> (Expr, Expr, Expr, Expr)
debugMovFunc func = func (x, y, z, w)

insertAt :: Int -> a -> [a] -> [a]
insertAt pos elm trg = (take pos trg) ++ [elm] ++ (drop pos trg)

paddedAll :: (Eq a) => a -> [a] -> [[a]]
paddedAll elm trg = trg : nub [padded n ary | ary <- paddedAll elm trg, n <- [0 .. length trg]]
  where padded n ary = insertAt n elm ary

pickSeq :: (a -> Bool) -> [a] -> [a]
pickSeq f = takeWhile f . dropWhile (not . f)

paddedValsSet :: Vals -> PaddedValsSet
paddedValsSet vals = pickSeq (\ x -> ((==) 4 (length x))) $ paddedAll Zero vals

shiftRelsByPaddedVals :: PaddedVals -> Rels -> Rels
shiftRelsByPaddedVals vals rels = foldr shift rels valsWithInd
  where valsWithInd = zip vals [0 .. length vals - 1]
        shift (val, ind) rels_ = if val == Zero then map (shiftRel ind) rels_ else rels_
--paddedLogics :: Logic -> [Logic]