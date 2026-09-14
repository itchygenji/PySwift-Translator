import multiprocessing as mp


def worker(x):
    print("worker", x)
    return x * x

if __name__ == "__main__":
    p = mp.Process(target=worker, args=(5,))
    p.start()
    p.join()
    with mp.Pool(processes=2) as pool:
        values = pool.map(worker, [1, 2, 3, 4])
        print("results", values)
