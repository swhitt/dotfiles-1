#!/usr/bin/env python
from subprocess import call
import os

# get all my repositories.
# TODO: automatically enumerate github

active = [
	'git@github.com:naggie/dotfiles.git',
	'git@github.com:naggie/naggie.github.com.git',
	'git@github.com:naggie/darksky.git',
	'git@github.com:naggie/dscrates.git',
	'git@github.com:naggie/megafilter.git',
	'git@github.com:naggie/speakers.git',
]

inactive = [
	'git@github.com:naggie/runuo.git',
	'git@github.com:naggie/nnplus.git',
	'git@github.com:naggie/ninja-motor-controller.git',
	'git@github.com:naggie/dschat.git',
	'git@github.com:naggie/DSPA.git',
	'git@github.com:naggie/averclock.git',
	'git@github.com:naggie/vosbox.git',
	'git@github.com:naggie/MLDASH.git',
	'git@github.com:naggie/algalon.git',
]

for repository in active:
	call(['git','clone','--recursive',repository])

os.makedirs('INACTIVE')
os.chdir('INACTIVE')

for repository in inactive:
	call(['git','clone','--recursive',repository])
