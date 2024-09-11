import subprocess


def extend_dimension(fname=None):

    if fname is not None:
        subprocess.run(["matlab", "-batch", "\""+fname+"\""])
    else:
        print("you need to supply a filename as an argument")