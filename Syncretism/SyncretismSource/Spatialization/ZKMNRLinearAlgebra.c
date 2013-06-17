//
//  ZKMNRLinearAlgebra.c
//  Syncretism
//
//  Created by Chandrasekhar Ramakrishnan on 26.10.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//




#import "ZKMNRLinearAlgebra.h"
#import <Accelerate/Accelerate.h>

int ZKMNRSolve(float* A, float* B, unsigned	order)
{

	__CLPK_integer n = order;			// A is an N x N matrix
	__CLPK_integer nrhs = 1;			// result should be 1 column
	__CLPK_integer lda = order;			// the leading dimension is basically a stride
	__CLPK_integer pivots[order];		// space for the pivot indicies
	__CLPK_integer ldb = order;			// the leading dimension is basically a stride
	__CLPK_integer info;				// the result info
	int result;

	result = 
		sgesv_(		&n,					// the order of the matrix
					&nrhs,				// the number of right hand sides (1)
					A,					// the matrix
					&lda,				// the stride for the A matrix
					pivots,				// memory for the pivot
					B,					// the result matrix (column matrix)
					&ldb,				// the stride for the B matrix
					&info);				// result info
	return info;
}

int ZKMNRLUDecomposition(float* A, long int* pivots, unsigned order)
{
	__CLPK_integer n = order;			// A is an N x N matrix
	__CLPK_integer lda = order;			// the leading dimension is basically a stride
	__CLPK_integer info;				// the result info
	int result;

	result = 
		sgetrf_(	&n,					// the number of rows
					&n,					// the number of columns
					A,					// the matrix
					&lda,				// the stride for the A matrix
					pivots,				// the pivots in the LU decomposition
					&info);				// result info
	return info;
}

int ZKMNRLUSolve(float* LU, long int* pivots, float* B, unsigned order)
{
	__CLPK_integer n = order;			// LU is an N x N matrix
	__CLPK_integer nrhs = 1;			// result should be 1 column
	__CLPK_integer lda = order;			// the leading dimension is basically a stride
	__CLPK_integer ldb = order;			// the leading dimension is basically a stride
	__CLPK_integer info;				// the result info
	int result;
	
	

	result = 
		sgetrs_(	"N",				// no transposition
					&n,					// the order of the matrix
					&nrhs,				// the number of right hand sides (1)
					LU,					// the matrix
					&lda,				// the stride for the A matrix
					pivots,				// the pivots in the LU decomposition
					B,					// the result matrix (column matrix)
					&ldb,				// the stride for the B matrix
					&info);				// result info
	return info;
}
