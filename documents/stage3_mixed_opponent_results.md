# Stage 3 Mixed-Opponent Gauntlet Results

Generated (UTC): 2026-05-26T21:34:07.677096+00:00

## Run Configuration

- Profiles: sprinter,gambler,expectimax
- Seeds: 20260526, 20260527, 20260528, 20260529, 20260530
- Games per seat: 100
- Max turns: 20000

## Gauntlet A

Opponents: assassin,tortoise,balanced

### Commands Run

```powershell
python -m wahoo.selfplay --benchmark-profiles sprinter,gambler,expectimax --benchmark-opponents assassin,tortoise,balanced --benchmark-games-per-seat 100 --max-turns 20000 --seed 20260526
```
```powershell
python -m wahoo.selfplay --benchmark-profiles sprinter,gambler,expectimax --benchmark-opponents assassin,tortoise,balanced --benchmark-games-per-seat 100 --max-turns 20000 --seed 20260527
```
```powershell
python -m wahoo.selfplay --benchmark-profiles sprinter,gambler,expectimax --benchmark-opponents assassin,tortoise,balanced --benchmark-games-per-seat 100 --max-turns 20000 --seed 20260528
```
```powershell
python -m wahoo.selfplay --benchmark-profiles sprinter,gambler,expectimax --benchmark-opponents assassin,tortoise,balanced --benchmark-games-per-seat 100 --max-turns 20000 --seed 20260529
```
```powershell
python -m wahoo.selfplay --benchmark-profiles sprinter,gambler,expectimax --benchmark-opponents assassin,tortoise,balanced --benchmark-games-per-seat 100 --max-turns 20000 --seed 20260530
```

### Seed 20260526

| Rank | Profile | Wins | Win % | Completed | Avg Turns | Avg Rolls | Avg Captures | Seat (R/G/Y/B) |
|------|---------|------|-------|-----------|-----------|-----------|--------------|----------------|
| 1 | gambler | 350 | 87.5% | 400/400 | 564.0 | 677.8 | 104.0 | 91 / 87 / 86 / 86 |
| 2 | sprinter | 339 | 84.8% | 400/400 | 541.7 | 650.8 | 97.1 | 84 / 83 / 86 / 86 |
| 3 | expectimax | 298 | 74.5% | 400/400 | 668.4 | 801.7 | 118.6 | 76 / 74 / 74 / 74 |

### Seed 20260527

| Rank | Profile | Wins | Win % | Completed | Avg Turns | Avg Rolls | Avg Captures | Seat (R/G/Y/B) |
|------|---------|------|-------|-----------|-----------|-----------|--------------|----------------|
| 1 | gambler | 352 | 88.0% | 400/400 | 575.5 | 690.0 | 106.2 | 89 / 82 / 91 / 90 |
| 2 | sprinter | 350 | 87.5% | 400/400 | 546.1 | 655.8 | 98.1 | 82 / 91 / 91 / 86 |
| 3 | expectimax | 308 | 77.0% | 400/400 | 641.2 | 769.7 | 114.3 | 74 / 80 / 79 / 75 |

### Seed 20260528

| Rank | Profile | Wins | Win % | Completed | Avg Turns | Avg Rolls | Avg Captures | Seat (R/G/Y/B) |
|------|---------|------|-------|-----------|-----------|-----------|--------------|----------------|
| 1 | sprinter | 348 | 87.0% | 400/400 | 534.0 | 641.1 | 94.9 | 85 / 87 / 84 / 92 |
| 2 | gambler | 343 | 85.8% | 400/400 | 571.0 | 684.4 | 105.3 | 84 / 89 / 84 / 86 |
| 3 | expectimax | 318 | 79.5% | 400/400 | 636.9 | 764.3 | 113.8 | 82 / 80 / 76 / 80 |

### Seed 20260529

| Rank | Profile | Wins | Win % | Completed | Avg Turns | Avg Rolls | Avg Captures | Seat (R/G/Y/B) |
|------|---------|------|-------|-----------|-----------|-----------|--------------|----------------|
| 1 | sprinter | 351 | 87.8% | 400/400 | 541.6 | 649.7 | 97.3 | 87 / 85 / 92 / 87 |
| 2 | gambler | 330 | 82.5% | 400/400 | 591.8 | 709.9 | 109.3 | 86 / 77 / 79 / 88 |
| 3 | expectimax | 314 | 78.5% | 400/400 | 639.8 | 768.4 | 113.9 | 74 / 83 / 78 / 79 |

### Seed 20260530

| Rank | Profile | Wins | Win % | Completed | Avg Turns | Avg Rolls | Avg Captures | Seat (R/G/Y/B) |
|------|---------|------|-------|-----------|-----------|-----------|--------------|----------------|
| 1 | sprinter | 353 | 88.2% | 400/400 | 524.1 | 629.0 | 93.7 | 90 / 92 / 84 / 87 |
| 2 | gambler | 345 | 86.2% | 400/400 | 560.1 | 672.3 | 103.2 | 88 / 84 / 83 / 90 |
| 3 | expectimax | 311 | 77.8% | 400/400 | 645.0 | 773.6 | 115.1 | 77 / 81 / 72 / 81 |

### Aggregate Across Standard Seeds

| Rank | Profile | Wins | Win % | Completed | Avg Turns | Avg Rolls | Avg Captures | Seat (R/G/Y/B) |
|------|---------|------|-------|-----------|-----------|-----------|--------------|----------------|
| 1 | sprinter | 1741 | 87.1% | 2000/2000 | 537.5 | 645.3 | 96.2 | 428 / 438 / 437 / 438 |
| 2 | gambler | 1720 | 86.0% | 2000/2000 | 572.5 | 686.9 | 105.6 | 438 / 419 / 423 / 440 |
| 3 | expectimax | 1549 | 77.5% | 2000/2000 | 646.3 | 775.5 | 115.1 | 383 / 398 / 379 / 389 |

## Gauntlet B

Opponents: gambler,gatekeeper,engineer

### Commands Run

```powershell
python -m wahoo.selfplay --benchmark-profiles sprinter,gambler,expectimax --benchmark-opponents gambler,gatekeeper,engineer --benchmark-games-per-seat 100 --max-turns 20000 --seed 20260526
```
```powershell
python -m wahoo.selfplay --benchmark-profiles sprinter,gambler,expectimax --benchmark-opponents gambler,gatekeeper,engineer --benchmark-games-per-seat 100 --max-turns 20000 --seed 20260527
```
```powershell
python -m wahoo.selfplay --benchmark-profiles sprinter,gambler,expectimax --benchmark-opponents gambler,gatekeeper,engineer --benchmark-games-per-seat 100 --max-turns 20000 --seed 20260528
```
```powershell
python -m wahoo.selfplay --benchmark-profiles sprinter,gambler,expectimax --benchmark-opponents gambler,gatekeeper,engineer --benchmark-games-per-seat 100 --max-turns 20000 --seed 20260529
```
```powershell
python -m wahoo.selfplay --benchmark-profiles sprinter,gambler,expectimax --benchmark-opponents gambler,gatekeeper,engineer --benchmark-games-per-seat 100 --max-turns 20000 --seed 20260530
```

### Seed 20260526

| Rank | Profile | Wins | Win % | Completed | Avg Turns | Avg Rolls | Avg Captures | Seat (R/G/Y/B) |
|------|---------|------|-------|-----------|-----------|-----------|--------------|----------------|
| 1 | sprinter | 201 | 50.2% | 400/400 | 437.7 | 526.0 | 70.3 | 45 / 50 / 56 / 50 |
| 2 | gambler | 191 | 47.8% | 400/400 | 433.1 | 520.7 | 71.9 | 49 / 51 / 38 / 53 |
| 3 | expectimax | 137 | 34.2% | 400/400 | 458.0 | 549.4 | 72.3 | 27 / 44 / 39 / 27 |

### Seed 20260527

| Rank | Profile | Wins | Win % | Completed | Avg Turns | Avg Rolls | Avg Captures | Seat (R/G/Y/B) |
|------|---------|------|-------|-----------|-----------|-----------|--------------|----------------|
| 1 | sprinter | 201 | 50.2% | 400/400 | 414.6 | 497.7 | 66.0 | 47 / 56 / 51 / 47 |
| 2 | gambler | 193 | 48.2% | 400/400 | 421.8 | 505.2 | 68.5 | 53 / 43 / 50 / 47 |
| 3 | expectimax | 132 | 33.0% | 400/400 | 458.5 | 550.3 | 72.0 | 29 / 37 / 44 / 22 |

### Seed 20260528

| Rank | Profile | Wins | Win % | Completed | Avg Turns | Avg Rolls | Avg Captures | Seat (R/G/Y/B) |
|------|---------|------|-------|-----------|-----------|-----------|--------------|----------------|
| 1 | sprinter | 210 | 52.5% | 400/400 | 417.0 | 500.8 | 66.7 | 58 / 59 / 45 / 48 |
| 2 | gambler | 209 | 52.2% | 400/400 | 440.3 | 528.4 | 72.5 | 50 / 47 / 61 / 51 |
| 3 | expectimax | 138 | 34.5% | 400/400 | 455.0 | 546.5 | 72.3 | 35 / 40 / 34 / 29 |

### Seed 20260529

| Rank | Profile | Wins | Win % | Completed | Avg Turns | Avg Rolls | Avg Captures | Seat (R/G/Y/B) |
|------|---------|------|-------|-----------|-----------|-----------|--------------|----------------|
| 1 | gambler | 186 | 46.5% | 400/400 | 439.9 | 527.7 | 72.5 | 50 / 39 / 49 / 48 |
| 2 | sprinter | 181 | 45.2% | 400/400 | 421.0 | 504.5 | 66.7 | 43 / 43 / 49 / 46 |
| 3 | expectimax | 151 | 37.8% | 400/400 | 454.6 | 546.4 | 72.3 | 31 / 47 / 36 / 37 |

### Seed 20260530

| Rank | Profile | Wins | Win % | Completed | Avg Turns | Avg Rolls | Avg Captures | Seat (R/G/Y/B) |
|------|---------|------|-------|-----------|-----------|-----------|--------------|----------------|
| 1 | sprinter | 217 | 54.2% | 400/400 | 428.8 | 514.7 | 68.6 | 55 / 60 / 50 / 52 |
| 2 | gambler | 205 | 51.2% | 400/400 | 443.5 | 532.4 | 73.2 | 55 / 46 / 49 / 55 |
| 3 | expectimax | 157 | 39.2% | 400/400 | 452.8 | 543.1 | 71.7 | 37 / 51 / 33 / 36 |

### Aggregate Across Standard Seeds

| Rank | Profile | Wins | Win % | Completed | Avg Turns | Avg Rolls | Avg Captures | Seat (R/G/Y/B) |
|------|---------|------|-------|-----------|-----------|-----------|--------------|----------------|
| 1 | sprinter | 1010 | 50.5% | 2000/2000 | 423.8 | 508.7 | 67.6 | 248 / 268 / 251 / 243 |
| 2 | gambler | 984 | 49.2% | 2000/2000 | 435.7 | 522.9 | 71.7 | 257 / 226 / 247 / 254 |
| 3 | expectimax | 715 | 35.8% | 2000/2000 | 455.8 | 547.2 | 72.1 | 159 / 219 / 186 / 151 |

## Gauntlet C

Opponents: random,balanced,balanced

### Commands Run

```powershell
python -m wahoo.selfplay --benchmark-profiles sprinter,gambler,expectimax --benchmark-opponents random,balanced,balanced --benchmark-games-per-seat 100 --max-turns 20000 --seed 20260526
```
```powershell
python -m wahoo.selfplay --benchmark-profiles sprinter,gambler,expectimax --benchmark-opponents random,balanced,balanced --benchmark-games-per-seat 100 --max-turns 20000 --seed 20260527
```
```powershell
python -m wahoo.selfplay --benchmark-profiles sprinter,gambler,expectimax --benchmark-opponents random,balanced,balanced --benchmark-games-per-seat 100 --max-turns 20000 --seed 20260528
```
```powershell
python -m wahoo.selfplay --benchmark-profiles sprinter,gambler,expectimax --benchmark-opponents random,balanced,balanced --benchmark-games-per-seat 100 --max-turns 20000 --seed 20260529
```
```powershell
python -m wahoo.selfplay --benchmark-profiles sprinter,gambler,expectimax --benchmark-opponents random,balanced,balanced --benchmark-games-per-seat 100 --max-turns 20000 --seed 20260530
```

### Seed 20260526

| Rank | Profile | Wins | Win % | Completed | Avg Turns | Avg Rolls | Avg Captures | Seat (R/G/Y/B) |
|------|---------|------|-------|-----------|-----------|-----------|--------------|----------------|
| 1 | sprinter | 298 | 74.5% | 400/400 | 467.1 | 561.3 | 71.9 | 80 / 75 / 77 / 66 |
| 2 | gambler | 297 | 74.2% | 400/400 | 475.4 | 571.5 | 75.7 | 79 / 67 / 69 / 82 |
| 3 | expectimax | 270 | 67.5% | 400/400 | 534.0 | 640.3 | 81.8 | 64 / 69 / 74 / 63 |

### Seed 20260527

| Rank | Profile | Wins | Win % | Completed | Avg Turns | Avg Rolls | Avg Captures | Seat (R/G/Y/B) |
|------|---------|------|-------|-----------|-----------|-----------|--------------|----------------|
| 1 | gambler | 305 | 76.2% | 400/400 | 479.0 | 574.5 | 76.2 | 72 / 75 / 76 / 82 |
| 2 | sprinter | 303 | 75.8% | 400/400 | 459.9 | 552.5 | 70.7 | 74 / 80 / 75 / 74 |
| 3 | expectimax | 245 | 61.3% | 400/400 | 544.8 | 654.5 | 83.9 | 54 / 65 / 63 / 63 |

### Seed 20260528

| Rank | Profile | Wins | Win % | Completed | Avg Turns | Avg Rolls | Avg Captures | Seat (R/G/Y/B) |
|------|---------|------|-------|-----------|-----------|-----------|--------------|----------------|
| 1 | sprinter | 314 | 78.5% | 400/400 | 460.6 | 553.0 | 70.7 | 87 / 76 / 72 / 79 |
| 2 | gambler | 312 | 78.0% | 400/400 | 492.4 | 591.1 | 79.2 | 71 / 81 / 82 / 78 |
| 3 | expectimax | 281 | 70.2% | 400/400 | 543.5 | 652.5 | 84.6 | 70 / 78 / 72 / 61 |

### Seed 20260529

| Rank | Profile | Wins | Win % | Completed | Avg Turns | Avg Rolls | Avg Captures | Seat (R/G/Y/B) |
|------|---------|------|-------|-----------|-----------|-----------|--------------|----------------|
| 1 | sprinter | 295 | 73.8% | 400/400 | 458.7 | 550.1 | 70.4 | 78 / 74 / 75 / 68 |
| 2 | gambler | 282 | 70.5% | 400/400 | 497.2 | 596.5 | 78.9 | 73 / 70 / 65 / 74 |
| 3 | expectimax | 275 | 68.8% | 400/400 | 544.7 | 654.2 | 83.4 | 60 / 77 / 71 / 67 |

### Seed 20260530

| Rank | Profile | Wins | Win % | Completed | Avg Turns | Avg Rolls | Avg Captures | Seat (R/G/Y/B) |
|------|---------|------|-------|-----------|-----------|-----------|--------------|----------------|
| 1 | sprinter | 312 | 78.0% | 400/400 | 461.6 | 553.8 | 70.6 | 75 / 82 / 76 / 79 |
| 2 | gambler | 303 | 75.8% | 400/400 | 482.0 | 579.0 | 76.6 | 80 / 78 / 66 / 79 |
| 3 | expectimax | 258 | 64.5% | 400/400 | 548.7 | 657.9 | 84.6 | 65 / 60 / 66 / 67 |

### Aggregate Across Standard Seeds

| Rank | Profile | Wins | Win % | Completed | Avg Turns | Avg Rolls | Avg Captures | Seat (R/G/Y/B) |
|------|---------|------|-------|-----------|-----------|-----------|--------------|----------------|
| 1 | sprinter | 1522 | 76.1% | 2000/2000 | 461.6 | 554.2 | 70.8 | 394 / 387 / 375 / 366 |
| 2 | gambler | 1499 | 75.0% | 2000/2000 | 485.2 | 582.5 | 77.3 | 375 / 371 / 358 / 395 |
| 3 | expectimax | 1329 | 66.5% | 2000/2000 | 543.1 | 651.9 | 83.7 | 313 / 349 / 346 / 321 |
