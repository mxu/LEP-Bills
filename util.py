#!/usr/local/bin/python3
import getopt, sys, os

def main(argv):
    try:
        opts, args = getopt.getopt(argv, 'c:', ['compare='])
    except getopt.GetoptError as e:
        print(e)
        usage()
        sys.exit(2)

    congressNum = 0

    for opt, arg in opts:
        if opt in ('-c', '--compare'):
            congressNum = arg
            oldData = getBills('Reports/{}/OldBills'.format(congressNum))
            newData = getBills('Reports/{}/Bills'.format(congressNum))
            print('     {:4}/{:4}/{:4}'.format('unim', 'regu', 'impo'))
            print('old: {:4}/{:4}/{:4}'.format(len(oldData[0]), len(oldData[1]), len(oldData[2])))
            print('new: {:4}/{:4}/{:4}'.format(len(newData[0]), len(newData[1]), len(newData[2])))
            print('\nunimportant: ')
            printDiff(oldData[0], newData[0])
            print('\nregular: ')
            printDiff(oldData[1], newData[1])
            print('\nimportant: ')
            printDiff(oldData[2], newData[2])

def printDiff(a, b):
    print('missing: ' + str([x for x in a if x not in b]))
    print('added:   ' + str([x for x in b if x not in a]))

def getBills(path):
    data = [[], [], []]
    files = os.listdir(path)
    for f in files:
        filepath = path + '/' + f
        # list of bills from first row, remove first col
        bills = open(filepath).readline().replace('"', '').strip().split(',')[1:]
        if '-important-' in f:
            data[2].extend(bills)
        elif '-regular-' in f:
            data[1].extend(bills)
        elif '-unimportant-' in f:
            data[0].extend(bills)
    return data

def usage():
    print('Usage')

if __name__ == '__main__':
    main(sys.argv[1:])