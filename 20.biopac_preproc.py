from __future__ import division

import os

import numpy as np
import matplotlib.pyplot as plt
import scipy.signal as sgn
import scipy.interpolate as spint
import scipy.stats as sct
import peakutils as pk


def create_hrf(newfreq=40):
	# Create HRF
	RT = 1/newfreq
	fMRI_T = 16
	p = [6,16,1,1,6,0,32]

	# Modelled hemodynamic response function - {mixture of Gammas}
	dt = RT / fMRI_T
	u = np.arange(0, p[6]/dt+1, 1) - p[5]/dt
	a1 = p[0] / p[2]
	b1 = 1 / p[3]
	a2 = p[1] / p[3] 
	b2 = 1 / p[3]
	hrf = (sct.gamma.pdf(u*dt, a1, scale = b1) - sct.gamma.pdf(u*dt, a2, scale = b2)/p[4])/dt
	time_axis = np.arange(0, int(p[6]/RT+1), 1) * fMRI_T
	hrf = hrf[time_axis]
	min_hrf = 1e-9*min(hrf[hrf > 10*np.finfo(float).eps])

	if min_hrf < 10*np.finfo(float).eps:
		min_hrf = 10*np.finfo(float).eps

	hrf[hrf == 0] = min_hrf
	hrf = hrf/max(hrf)

	plt.figure()
	plt.plot(hrf)

	return hrf


def prep_data(filename, tr=1.5, newfreq=40):
	data = np.genfromtxt(filename + '.acq.tsv.gz')
	idz=(data[:,0]>=0).argmax()
	data=data[idz:,]
	f = spint.interp1d(data[idz:,0],data[idz:,],axis=0,fill_value='extrapolate')
	data_tdec = np.arange(0,data[-1,0],1/newfreq)
	data_dec = f(data_tdec)

	del data,idz

	np.savetxt(filename + '_dec.tsv.gz',data_dec)

	return data_dec


def filter_signal(data_dec,channel=4):
	ba = sgn.butter(7, 2/20, 'lowpass')
	resp_filt = sgn.filtfilt(ba[0],ba[1],data_dec[:,channel])
	plt.figure()
	plt.plot(resp_filt)

	return resp_filt


def get_peaks(resp_filt):
	# Finding peaks
	co = sgn.detrend(resp_filt, type='linear', bp=0)
	pidx = pk.peak.indexes(co,thres=0.5,min_dist=120).tolist()
	plt.figure()
	plt.plot(co)
	plt.plot(co,'m*',markevery=pidx)
	# pidx = np.delete(pidx,[56])
	return co,pidx


def get_petco2(co,pidx,hrf,filename,ign_tr=400):
	# Extract PETco2
	coln = len(co)
	nx = np.linspace(0,coln,coln)
	f = spint.interp1d(pidx,co[pidx],fill_value='extrapolate')
	co_int = f(nx)
	co_int = co_int-(np.mean(co_int))
	plt.figure()
	plt.plot(co_int)
	# np.savetxt('co_int.1D',co_int,fmt='%.18f')

	co_conv = np.convolve(co_int,hrf)
	coln = coln - ign_tr
	co_conv = co_conv[ign_tr:coln]
	plt.figure()
	plt.plot(co_conv,'-',co_int*100,'-')

	np.savetxt(filename + '_co_conv.1D',co_conv,fmt='%.18f')

	return co_conv


def get_regr(GM_name, co_conv, tr=1.5, newfreq=40 ):
	GM = np.genfromtxt(GM_name)

	# Interpolate GMOC at 40 Hz
	atps = len(GM)
	f = spint.interp1d(np.linspace(0,atps*tr,atps),GM,fill_value='extrapolate')
	nGMx = np.arange(0,atps*tr,1/newfreq)
	GM_40 = f(nGMx)
	GMln_40 = len(nGMx)

	# Detrend GM
	GM_dt = sgn.detrend(GM_40, type='linear', bp=0)
	plt.figure()
	plt.plot(GM_dt)

	gmnrep = len(co_conv) - GMln_40
	GM_r = np.zeros((gmnrep))
	for k in range(0,gmnrep):
		GM_r[k] = np.corrcoef(GM_dt,co_conv[0+k:GMln_40+k].T)[1,0]

	tax = np.arange(0,gmnrep/newfreq,1/newfreq)
	plt.figure()
	plt.plot(tax,GM_r)
	optshift = int(GM_r.argmax(0))
	co_shift = co_conv[optshift:optshift+GMln_40]

	plt.figure()
	plt.plot(sct.zscore(GM_dt))
	plt.plot(sct.zscore(co_shift))

	# Interpolate CO_CONV at TR
	f = spint.interp1d(np.linspace(0,GMln_40,GMln_40),co_shift,fill_value='extrapolate')
	trx = np.linspace(0,GMln_40,round(GMln_40/newfreq/tr))
	co_tr = f(trx)
	plt.figure()
	plt.plot(co_tr)
	co_dm = co_tr - np.mean(co_tr)
	textname = GM_name + '_co_regr.1D'
	np.savetxt(textname,co_dm,fmt='%.18f')

	# Prepare number of repetitions
	rnrep = int(newfreq*tr*6)
	if optshift-rnrep < 0:
		repmin = -optshift
	else:
		repmin = -rnrep

	if optshift+rnrep+GMln_40 > len(co_conv):
		repmax = len(co_conv)-optshift-GMln_40
	else:
		repmax = rnrep

	# Save regressors
	GM_dir = GM_name + '_regr_shift'
	os.mkdir(GM_dir)

	for k in range(repmin,repmax+1):
		co_shift = co_conv[optshift+k:optshift+GMln_40+k]
		f = spint.interp1d(np.linspace(0,GMln_40,GMln_40),co_shift,fill_value='extrapolate')
		co_tr = f(trx)
		co_dm = co_tr - np.mean(co_tr)
		txtname = GM_dir + '/shift_' + '%04d' % (k + rnrep) + '.1D'
		np.savetxt(txtname,co_dm,fmt='%.18f')


def partone(filename,channel=4):
	#data_dec = prep_data(filename)
	data_dec = np.genfromtxt(filename + '_BH_dec.tsv.gz')
	resp_filt = filter_signal(data_dec,channel)
	[co,pidx] = get_peaks(resp_filt)
	plt.plot(co)
	plt.plot(co,'m*',markevery=pidx)
	return co,pidx
	

# def parttwo(co,pidx,filename):
def parttwo(filename):
	# hrf = create_hrf()
	# co_conv = get_petco2(co,pidx,hrf,filename)
	co_conv = np.genfromtxt('regr/' + filename + '_co_conv.1D')
	GM_name = filename + '_GM_melodic'
	get_regr(GM_name,co_conv)
	GM_name = filename + '_GM_skundu'
	get_regr(GM_name,co_conv)


if __name__ == '__main__':
	# Reading first data
	newfreq=40
	# nrep = 2000
	tr=1.5
	# tps=340

	co, pidx = parone(filename, channel=4)
	parttwo(co, pidx, filename)