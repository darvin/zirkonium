//
//  ZKMNRLinearAlgebra.h
//  Syncretism
//
//  Created by Chandrasekhar Ramakrishnan on 26.10.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//
//  Linear Algebra utility functions. These call through to LAPACK / BLAS, but
//  present a simplified interface.
// 

#ifndef __ZKMNRLinearAlgebra_h__
#define __ZKMNRLinearAlgebra_h__

#include "ZKMORCore.h"

ZKMOR_C_BEGIN

///
///	ZKMNRSolve
///
///  Solve the system of linear equations of the form Ax = B
///  (A is NxN, X and B are 1xN). Uses LAPACK SGESV. (N == 2, 3)
///  see <http://www.netlib.org/lapack/single/sgesv.f>
///
///  returns 
///		  0 on no error, 
///		< 0 if there was an error in the data
///		> 0 if the matrix is singular
///  Overwrites A with the LU decomposition and B with the values for x.
///
int ZKMNRSolve(float* A, float* B, unsigned	order);

///
///	ZKMNRLUDecomposition
///
///  Decomposes the matrix A as a combination of an upper triangular,
///  lower triangular, and permutation matrix.
///  (A is NxN). Uses LAPACK SGETRF. (N == 2, 3)
///  see <http://www.netlib.org/lapack/single/sgetrf.f>
///  returns 
///		  0 on no error, 
///		< 0 if there was an error in the data
///		> 0 if the matrix is singular
///  Overwrites A with the LU decomposition
///
int ZKMNRLUDecomposition(float* A, long int* pivots, unsigned order);

///
///	ZKMNRLUSolve
///
///  Solve the system of linear equations of the form Ax = B,
///  given the LU decomposition of A.
///  (A is NxN, X and B are 1xN). Uses LAPACK SGETRS. (N == 2, 3)
///  see <http://www.netlib.org/lapack/single/sgetrs.f>
///  returns 
///		  0 on no error, 
///		< 0 if there was an error in the data
///
int ZKMNRLUSolve(float* LU, long int* pivots, float* B, unsigned order);

ZKMOR_C_END

#endif __ZKMNRCoordinates_h__