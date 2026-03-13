
# Running main program
import argparse
from src.main import main


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="City-Sim")
    parser.add_argument(
        "--gui",
        action="store_true",
        help="Launch with the isometric 2D renderer (requires pygame-ce)",
    )
    args = parser.parse_args()
    main(gui=args.gui)
