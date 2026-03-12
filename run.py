
# Running main program
import sys
from src.main import main


if __name__ == "__main__":
    main(gui="--gui" in sys.argv)
