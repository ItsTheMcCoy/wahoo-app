# Stage 4 Pairwise Confirmation Results

Generated (UTC): 2026-05-26T22:59:01.408798+00:00

## Run Configuration

- Profiles: sprinter,gambler,expectimax
- Layouts: 1, 2, 3, 4
- Seeds: 20260531, 20260532, 20260533, 20260534
- Games per layout: 500
- Max turns: 20000

## Pair sprinter vs gambler

### Commands Run

```powershell
python -m wahoo.selfplay --games 500 --players sprinter,gambler,sprinter,gambler --max-turns 20000 --seed 20260531
```
```powershell
python -m wahoo.selfplay --games 500 --players gambler,sprinter,gambler,sprinter --max-turns 20000 --seed 20260532
```
```powershell
python -m wahoo.selfplay --games 500 --players sprinter,sprinter,gambler,gambler --max-turns 20000 --seed 20260533
```
```powershell
python -m wahoo.selfplay --games 500 --players gambler,gambler,sprinter,sprinter --max-turns 20000 --seed 20260534
```

### Layout Results

| Layout | Seed | Lineup | Games | Completed | Unfinished | Wins sprinter | Wins gambler | Avg Turns | Avg Rolls | Avg Captures |
|--------|------|--------|-------|-----------|------------|----------------|----------------|-----------|-----------|--------------|
| 1 | 20260531 | sprinter,gambler,sprinter,gambler | 500 | 500 | 0 | 256 | 244 | 324.8 | 389.3 | 40.6 |
| 2 | 20260532 | gambler,sprinter,gambler,sprinter | 500 | 500 | 0 | 275 | 225 | 321.1 | 384.9 | 40.3 |
| 3 | 20260533 | sprinter,sprinter,gambler,gambler | 500 | 500 | 0 | 254 | 246 | 319.5 | 383.6 | 40.3 |
| 4 | 20260534 | gambler,gambler,sprinter,sprinter | 500 | 500 | 0 | 273 | 227 | 321.7 | 385.7 | 40.3 |

### Aggregate Across Layouts

| Rank | Profile | Wins | Win % | Completed | Unfinished | Avg Turns | Avg Rolls | Avg Captures |
|------|---------|------|-------|-----------|------------|-----------|-----------|--------------|
| 1 | sprinter | 1058 | 52.9% | 2000/2000 | 0 | 321.8 | 385.9 | 40.4 |
| 2 | gambler | 942 | 47.1% | 2000/2000 | 0 | 321.8 | 385.9 | 40.4 |

Winner: sprinter by 5.8 percentage points on aggregate win rate.

## Pair sprinter vs expectimax

### Commands Run

```powershell
python -m wahoo.selfplay --games 500 --players sprinter,expectimax,sprinter,expectimax --max-turns 20000 --seed 20260531
```
```powershell
python -m wahoo.selfplay --games 500 --players expectimax,sprinter,expectimax,sprinter --max-turns 20000 --seed 20260532
```
```powershell
python -m wahoo.selfplay --games 500 --players sprinter,sprinter,expectimax,expectimax --max-turns 20000 --seed 20260533
```
```powershell
python -m wahoo.selfplay --games 500 --players expectimax,expectimax,sprinter,sprinter --max-turns 20000 --seed 20260534
```

### Layout Results

| Layout | Seed | Lineup | Games | Completed | Unfinished | Wins sprinter | Wins expectimax | Avg Turns | Avg Rolls | Avg Captures |
|--------|------|--------|-------|-----------|------------|----------------|----------------|-----------|-----------|--------------|
| 1 | 20260531 | sprinter,expectimax,sprinter,expectimax | 500 | 500 | 0 | 282 | 218 | 319.2 | 382.5 | 33.3 |
| 2 | 20260532 | expectimax,sprinter,expectimax,sprinter | 500 | 500 | 0 | 306 | 194 | 318.7 | 382.2 | 33.4 |
| 3 | 20260533 | sprinter,sprinter,expectimax,expectimax | 500 | 500 | 0 | 317 | 183 | 325.1 | 390.2 | 34.3 |
| 4 | 20260534 | expectimax,expectimax,sprinter,sprinter | 500 | 500 | 0 | 289 | 211 | 322.6 | 386.6 | 34.0 |

### Aggregate Across Layouts

| Rank | Profile | Wins | Win % | Completed | Unfinished | Avg Turns | Avg Rolls | Avg Captures |
|------|---------|------|-------|-----------|------------|-----------|-----------|--------------|
| 1 | sprinter | 1194 | 59.7% | 2000/2000 | 0 | 321.4 | 385.4 | 33.8 |
| 2 | expectimax | 806 | 40.3% | 2000/2000 | 0 | 321.4 | 385.4 | 33.8 |

Winner: sprinter by 19.4 percentage points on aggregate win rate.

## Pair gambler vs expectimax

### Commands Run

```powershell
python -m wahoo.selfplay --games 500 --players gambler,expectimax,gambler,expectimax --max-turns 20000 --seed 20260531
```
```powershell
python -m wahoo.selfplay --games 500 --players expectimax,gambler,expectimax,gambler --max-turns 20000 --seed 20260532
```
```powershell
python -m wahoo.selfplay --games 500 --players gambler,gambler,expectimax,expectimax --max-turns 20000 --seed 20260533
```
```powershell
python -m wahoo.selfplay --games 500 --players expectimax,expectimax,gambler,gambler --max-turns 20000 --seed 20260534
```

### Layout Results

| Layout | Seed | Lineup | Games | Completed | Unfinished | Wins gambler | Wins expectimax | Avg Turns | Avg Rolls | Avg Captures |
|--------|------|--------|-------|-----------|------------|----------------|----------------|-----------|-----------|--------------|
| 1 | 20260531 | gambler,expectimax,gambler,expectimax | 500 | 500 | 0 | 295 | 205 | 339.9 | 407.4 | 38.6 |
| 2 | 20260532 | expectimax,gambler,expectimax,gambler | 500 | 500 | 0 | 296 | 204 | 338.7 | 406.4 | 38.5 |
| 3 | 20260533 | gambler,gambler,expectimax,expectimax | 500 | 500 | 0 | 289 | 211 | 332.2 | 398.7 | 38.1 |
| 4 | 20260534 | expectimax,expectimax,gambler,gambler | 500 | 500 | 0 | 281 | 219 | 343.8 | 412.2 | 39.5 |

### Aggregate Across Layouts

| Rank | Profile | Wins | Win % | Completed | Unfinished | Avg Turns | Avg Rolls | Avg Captures |
|------|---------|------|-------|-----------|------------|-----------|-----------|--------------|
| 1 | gambler | 1161 | 58.1% | 2000/2000 | 0 | 338.7 | 406.2 | 38.7 |
| 2 | expectimax | 839 | 41.9% | 2000/2000 | 0 | 338.7 | 406.2 | 38.7 |

Winner: gambler by 16.1 percentage points on aggregate win rate.
