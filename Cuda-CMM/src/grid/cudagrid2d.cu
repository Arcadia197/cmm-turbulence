#include "cudagrid2d.h"


TCudaGrid2D::TCudaGrid2D(int NX, int NY, double xRange)
{
	this->NX = NX;
	this->NY = NY;
	
	this->h = xRange/(float)NX;
	
	this->N = NX*NY;
	this->sizeNReal = sizeof(double)*N;
	this->sizeNComplex = sizeof(cufftDoubleComplex)*N;

	//block & grid
	threadsPerBlock.x = BLOCK_SIZE;
	threadsPerBlock.y = BLOCK_SIZE;
	threadsPerBlock.z = 1;

	blocksPerGrid.x = ceil((float)NX/threadsPerBlock.x);
	blocksPerGrid.y = ceil((float)NY/threadsPerBlock.y);
	blocksPerGrid.z = 1;
}


MapStack::MapStack(TCudaGrid2D *Grid, int cpu_map_num)
{

	this->Grid = Grid;

	this->cpu_map_num = cpu_map_num;

	// set values
	map_stack_ctr = 0;
	Nb_array_RAM = 4;

	// initialize device map stack
	cudaMalloc((void **) &Dev_ChiX_stack, 4*Grid->sizeNReal);
	cudaMalloc((void **) &Dev_ChiY_stack, 4*Grid->sizeNReal);

	Host_ChiX_stack_RAM_0 = new double[cpu_map_num * 4*Grid->sizeNReal];
	Host_ChiY_stack_RAM_0 = new double[cpu_map_num * 4*Grid->sizeNReal];
	Host_ChiX_stack_RAM_1 = new double[cpu_map_num * 4*Grid->sizeNReal];
	Host_ChiY_stack_RAM_1 = new double[cpu_map_num * 4*Grid->sizeNReal];
	Host_ChiX_stack_RAM_2 = new double[cpu_map_num * 4*Grid->sizeNReal];
	Host_ChiY_stack_RAM_2 = new double[cpu_map_num * 4*Grid->sizeNReal];
	Host_ChiX_stack_RAM_3 = new double[cpu_map_num * 4*Grid->sizeNReal];
	Host_ChiY_stack_RAM_3 = new double[cpu_map_num * 4*Grid->sizeNReal];
}


// copy inserted map into last position at map stack, after 1/4 of all total maps, start using new array
void MapStack::copy_map_to_host(double *Dev_ChiX, double *Dev_ChiY) {
    switch(map_stack_ctr / cpu_map_num){
        case 0:
            cudaMemcpy(&Host_ChiX_stack_RAM_0[(map_stack_ctr%cpu_map_num)*4*Grid->N], Dev_ChiX, 4*Grid->sizeNReal, cudaMemcpyDeviceToHost);
            cudaMemcpy(&Host_ChiY_stack_RAM_0[(map_stack_ctr%cpu_map_num)*4*Grid->N], Dev_ChiY, 4*Grid->sizeNReal, cudaMemcpyDeviceToHost);
            break;
        case 1:
            cudaMemcpy(&Host_ChiX_stack_RAM_1[(map_stack_ctr%cpu_map_num)*4*Grid->N], Dev_ChiX, 4*Grid->sizeNReal, cudaMemcpyDeviceToHost);
            cudaMemcpy(&Host_ChiY_stack_RAM_1[(map_stack_ctr%cpu_map_num)*4*Grid->N], Dev_ChiY, 4*Grid->sizeNReal, cudaMemcpyDeviceToHost);
            break;
        case 2:
            cudaMemcpy(&Host_ChiX_stack_RAM_2[(map_stack_ctr%cpu_map_num)*4*Grid->N], Dev_ChiX, 4*Grid->sizeNReal, cudaMemcpyDeviceToHost);
            cudaMemcpy(&Host_ChiY_stack_RAM_2[(map_stack_ctr%cpu_map_num)*4*Grid->N], Dev_ChiY, 4*Grid->sizeNReal, cudaMemcpyDeviceToHost);
            break;

        case 3:
            cudaMemcpy(&Host_ChiX_stack_RAM_3[(map_stack_ctr%cpu_map_num)*4*Grid->N], Dev_ChiX, 4*Grid->sizeNReal, cudaMemcpyDeviceToHost);
            cudaMemcpy(&Host_ChiY_stack_RAM_3[(map_stack_ctr%cpu_map_num)*4*Grid->N], Dev_ChiY, 4*Grid->sizeNReal, cudaMemcpyDeviceToHost);
            break;
    }
    map_stack_ctr++;
}
// copy map to device, map_num decides which map to take out
void MapStack::copy_map_to_device(int map_num) {
	switch (map_num / cpu_map_num) {
		case 0: {
			cudaMemcpy(Dev_ChiX_stack, &Host_ChiX_stack_RAM_0[(map_num%cpu_map_num)*Grid->N*4], 4*Grid->sizeNReal, cudaMemcpyHostToDevice);
			cudaMemcpy(Dev_ChiY_stack, &Host_ChiY_stack_RAM_0[(map_num%cpu_map_num)*Grid->N*4], 4*Grid->sizeNReal, cudaMemcpyHostToDevice);
			break;
		}
		case 1: {
			cudaMemcpy(Dev_ChiX_stack, &Host_ChiX_stack_RAM_1[(map_num%cpu_map_num)*Grid->N*4], 4*Grid->sizeNReal, cudaMemcpyHostToDevice);
			cudaMemcpy(Dev_ChiY_stack, &Host_ChiY_stack_RAM_1[(map_num%cpu_map_num)*Grid->N*4], 4*Grid->sizeNReal, cudaMemcpyHostToDevice);
			break;
		}
		case 2: {
			cudaMemcpy(Dev_ChiX_stack, &Host_ChiX_stack_RAM_2[(map_num%cpu_map_num)*Grid->N*4], 4*Grid->sizeNReal, cudaMemcpyHostToDevice);
			cudaMemcpy(Dev_ChiY_stack, &Host_ChiY_stack_RAM_2[(map_num%cpu_map_num)*Grid->N*4], 4*Grid->sizeNReal, cudaMemcpyHostToDevice);
			break;
		}
		case 3: {
			cudaMemcpy(Dev_ChiX_stack, &Host_ChiX_stack_RAM_3[(map_num%cpu_map_num)*Grid->N*4], 4*Grid->sizeNReal, cudaMemcpyHostToDevice);
			cudaMemcpy(Dev_ChiY_stack, &Host_ChiY_stack_RAM_3[(map_num%cpu_map_num)*Grid->N*4], 4*Grid->sizeNReal, cudaMemcpyHostToDevice);
			break;
		}
	}
}

// free those resources
void MapStack::free_res() {
	delete [] Host_ChiX_stack_RAM_0;
	delete [] Host_ChiY_stack_RAM_0;
	delete [] Host_ChiX_stack_RAM_1;
	delete [] Host_ChiY_stack_RAM_1;
	delete [] Host_ChiX_stack_RAM_2;
	delete [] Host_ChiY_stack_RAM_2;
	delete [] Host_ChiX_stack_RAM_3;
	delete [] Host_ChiY_stack_RAM_3;
	cudaFree(Dev_ChiX_stack);
	cudaFree(Dev_ChiY_stack);
}
