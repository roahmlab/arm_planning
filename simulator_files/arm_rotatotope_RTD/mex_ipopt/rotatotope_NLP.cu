/*
Author: Bohao Zhang
Dec. 19 2019

arm_planning mex

ipopt nlp for rotatotopes
*/

#ifndef ROTATOTOPE_NLP_CPP
#define ROTATOTOPE_NLP_CPP

#include "rotatotope_NLP.h"

#ifdef __GNUC__
#pragma GCC diagnostic ignored "-Wunused-parameter"
#endif

// constructor
rotatotope_NLP::rotatotope_NLP()
{
    ra_info = nullptr;
    q = nullptr;
    q_dot = nullptr;
    q_des = nullptr;
    n_obstacles = 0;
    solution = nullptr;
}

// destructor
rotatotope_NLP::~rotatotope_NLP()
{
    if(solution != nullptr){
       delete[] solution;
    }
}

 // [set_parameters]
 // set needed parameters
 bool rotatotope_NLP::set_parameters(
    rotatotopeArray* ra_input,
    double* q_input,
    double* q_dot_input,
    double* q_des_input,
    double* c_k_input,
    double* g_k_input,
    uint32_t n_obstacles_input
 )
 {
    ra_info = ra_input;
    q = q_input;
    q_dot = q_dot_input;
    q_des = q_des_input;
    c_k = c_k_input;
    g_k = g_k_input;
    n_obstacles = n_obstacles_input;
    return true;
 };

// [TNLP_get_nlp_info]
// returns the size of the problem
bool rotatotope_NLP::get_nlp_info(
   Index&          n,
   Index&          m,
   Index&          nnz_jac_g,
   Index&          nnz_h_lag,
   IndexStyleEnum& index_style
)
{
   // The problem described 6 variables, x[0] through x[5] for each joint
   n = ra_info->n_links * 2;

   // number of inequality constraint
   m = ra_info->n_links * n_obstacles * ra_info->n_time_steps;

   nnz_jac_g = m * n;
   nnz_h_lag = n * (n + 1) / 2;

   // use the C style indexing (0-based)
   index_style = TNLP::C_STYLE;

   return true;
}
// [TNLP_get_nlp_info]

// [TNLP_get_bounds_info]
// returns the variable bounds
bool rotatotope_NLP::get_bounds_info(
   Index   n,
   Number* x_l,
   Number* x_u,
   Index   m,
   Number* g_l,
   Number* g_u
)
{
   // here, the n and m we gave IPOPT in get_nlp_info are passed back to us.
   // If desired, we could assert to make sure they are what we think they are.
   if(n != ra_info->n_links * 2){
      mexErrMsgIdAndTxt("MyProg:ConvertString", "*** Error wrong value of n in get_bounds_info!");
   }
   if(m != ra_info->n_links * n_obstacles * ra_info->n_time_steps){
      mexErrMsgIdAndTxt("MyProg:ConvertString", "*** Error wrong value of m in get_bounds_info!");
   }

   // lower bounds
   for( Index i = 0; i < n; i++ ) {
      x_l[i] = c_k[i] - g_k[i];
   }

   // upper bounds  
   for( Index i = 0; i < n; i++ ) {
      x_u[i] = c_k[i] + g_k[i];
   }

   for( Index i = 0; i < m; i++ ) {
      // constraint has a lower bound of inf
      g_l[i] = -2e19;
      // constraint has an upper bound of 0
      g_u[i] = 0;
   }

   return true;
}
// [TNLP_get_bounds_info]

// [TNLP_get_starting_point]
// returns the initial point for the problem
bool rotatotope_NLP::get_starting_point(
   Index   n,
   bool    init_x,
   Number* x,
   bool    init_z,
   Number* z_L,
   Number* z_U,
   Index   m,
   bool    init_lambda,
   Number* lambda
)
{
   // Here, we assume we only have starting values for x, if you code
   // your own NLP, you can provide starting values for the dual variables
   // if you wish
   if(init_x == false || init_z == true || init_lambda == true){
       mexErrMsgIdAndTxt("MyProg:ConvertString", "*** Error wrong value of init in get_starting_point!");
   }

   if(n != ra_info->n_links * 2){
      mexErrMsgIdAndTxt("MyProg:ConvertString", "*** Error wrong value of n in get_starting_point!");
   }

   // initialize to the given starting point
   for( Index i = 0; i < n; i++ ) {
      x[i] = c_k[i];
   }

   return true;
}
// [TNLP_get_starting_point]

// [TNLP_eval_f]
// returns the value of the objective function
bool rotatotope_NLP::eval_f(
   Index         n,
   const Number* x,
   bool          new_x,
   Number&       obj_value
)
{
   if(n != ra_info->n_links * 2){
      mexErrMsgIdAndTxt("MyProg:ConvertString", "*** Error wrong value of n in eval_f!");
   }

   // q_plan = q_0 + q_dot_0*P.t_plan + (1/2)*k*P.t_plan^2;
   // obj_value = sum((q_plan - q_des).^2);
   obj_value = 0; 
   for(Index i = 0; i < ra_info->n_links * 2; i++){
       double entry = q[i] + q_dot[i] * t_plan + x[i] * t_plan * t_plan / 2 - q_des[i];
       obj_value += entry * entry;
   }

   return true;
}
// [TNLP_eval_f]

// [TNLP_eval_grad_f]
// return the gradient of the objective function grad_{x} f(x)
bool rotatotope_NLP::eval_grad_f(
   Index         n,
   const Number* x,
   bool          new_x,
   Number*       grad_f
)
{
   if(n != ra_info->n_links * 2){
      mexErrMsgIdAndTxt("MyProg:ConvertString", "*** Error wrong value of n in eval_grad_f!");
   }

   for(Index i = 0; i < ra_info->n_links * 2; i++){
        double entry = q[i] + q_dot[i] * t_plan + x[i] * t_plan * t_plan / 2 - q_des[i];
        grad_f[i] = t_plan * t_plan * entry;
   }

   return true;
}
// [TNLP_eval_grad_f]

// [TNLP_eval_g]
// return the value of the constraints: g(x)
bool rotatotope_NLP::eval_g(
   Index         n,
   const Number* x,
   bool          new_x,
   Index         m,
   Number*       g
)
{
   if(n != ra_info->n_links * 2){
      mexErrMsgIdAndTxt("MyProg:ConvertString", "*** Error wrong value of n in eval_g!");
   }
   if(m != ra_info->n_links * n_obstacles * ra_info->n_time_steps){
      mexErrMsgIdAndTxt("MyProg:ConvertString", "*** Error wrong value of m in eval_g!");
   }
   
   bool compute_new_constraints;
   if(ra_info->current_k_opt != nullptr){
        compute_new_constraints = false;
        for(uint32_t i = 0; i < n; i++){
            if(ra_info->current_k_opt[i] != x[i]){
                compute_new_constraints = true;
                break;
            }
        }
    }
    else{
        compute_new_constraints = true;
    }

    if(compute_new_constraints){
        double* x_double = new double[n];
        for(uint32_t i = 0; i < n; i++){
            x_double[i] = (double)x[i];
        }
        ra_info->evaluate_constraints(x_double);
        delete[] x_double;
    }

   for(Index i = 0; i < m; i++) {
        g[i] = ra_info->con[i];
   }

   return true;
}
// [TNLP_eval_g]

// [TNLP_eval_jac_g]
// return the structure or values of the Jacobian
bool rotatotope_NLP::eval_jac_g(
   Index         n,
   const Number* x,
   bool          new_x,
   Index         m,
   Index         nele_jac,
   Index*        iRow,
   Index*        jCol,
   Number*       values
)
{
   if(n != ra_info->n_links * 2){
      mexErrMsgIdAndTxt("MyProg:ConvertString", "*** Error wrong value of n in eval_jac_g!");
   }
   if(m != ra_info->n_links * n_obstacles * ra_info->n_time_steps){
      mexErrMsgIdAndTxt("MyProg:ConvertString", "*** Error wrong value of m in eval_jac_g!");
   }

   if( values == NULL ) {
      // return the structure of the Jacobian
      // this particular Jacobian is dense
      for(Index i = 0; i < m; i++){
          for(Index j = 0; j < n; j++){
              iRow[i * n + j] = i;
              jCol[i * n + j] = j;
          }
      }
   }
   else {
      bool compute_new_constraints;
      if(ra_info->current_k_opt != nullptr){
         compute_new_constraints = false;
         for(uint32_t i = 0; i < n; i++){
            if(ra_info->current_k_opt[i] != x[i]){
               compute_new_constraints = true;
               break;
            }
         }
      }
      else{
         compute_new_constraints = true;
      }
   
      if(compute_new_constraints){
         double* x_double = new double[n];
         for(uint32_t i = 0; i < n; i++){
            x_double[i] = (double)x[i];
         }
         ra_info->evaluate_constraints(x_double);
         delete[] x_double;
      }
      
      // return the values of the Jacobian of the constraints
      for(Index i = 0; i < m; i++){
          for(Index j = 0; j < n; j++){
              values[i * n + j] = ra_info->jaco_con[i * n + j];
          }
      }
   }

   return true;
}
// [TNLP_eval_jac_g]

// [TNLP_eval_h]
//return the structure or values of the Hessian
bool rotatotope_NLP::eval_h(
   Index         n,
   const Number* x,
   bool          new_x,
   Number        obj_factor,
   Index         m,
   const Number* lambda,
   bool          new_lambda,
   Index         nele_hess,
   Index*        iRow,
   Index*        jCol,
   Number*       values
)
{
   if(n != ra_info->n_links * 2){
      mexErrMsgIdAndTxt("MyProg:ConvertString", "*** Error wrong value of n in eval_h!");
   }
   if(m != ra_info->n_links * n_obstacles * ra_info->n_time_steps){
      mexErrMsgIdAndTxt("MyProg:ConvertString", "*** Error wrong value of m in eval_h!");
   }

   if (values == NULL) {
      // return the structure. This is a symmetric matrix, fill the lower left
      // triangle only.
  
      // the Hessian for this problem is actually dense
      Index idx = 0;
      for (Index row = 0; row < n; row++) {
        for (Index col = 0; col <= row; col++) {
          iRow[idx] = row; 
          jCol[idx] = col;
          idx++;
        }
      }
      
      if(idx != nele_hess){
         mexErrMsgIdAndTxt("MyProg:ConvertString", "*** Error wrong size of hessian in eval_h!");
      }
    }
    else {
      bool compute_new_constraints;
      if(ra_info->current_k_opt != nullptr){
         compute_new_constraints = false;
         for(uint32_t i = 0; i < n; i++){
            if(ra_info->current_k_opt[i] != x[i]){
               compute_new_constraints = true;
               break;
            }
         }
      }
      else{
         compute_new_constraints = true;
      }
   
      if(compute_new_constraints){
         double* x_double = new double[n];
         for(uint32_t i = 0; i < n; i++){
            x_double[i] = (double)x[i];
         }
         ra_info->evaluate_constraints(x_double);
         delete[] x_double;
      }

      Index idx = 0;
      for (Index row = 0; row < n; row++) {
         for (Index col = 0; col <= row; col++) {
            if(row == col){
               values[idx] = obj_factor * t_plan * t_plan * t_plan * t_plan / 2;
            }
            else{
               values[idx] = 0;
            }
            idx++;
         }
      }

      for(Index i = 0; i < m; i++){
         idx = 0;
         for (Index row = 0; row < n; row++) {
            for (Index col = 0; col < row; col++) {
               values[idx] += lambda[i] * ra_info->hess_con[i * n * (n - 1) / 2 + idx];
               idx++;
            }
         }
      }
    }

   return true;
}
// [TNLP_eval_h]

// [TNLP_finalize_solution]
void rotatotope_NLP::finalize_solution(
   SolverReturn               status,
   Index                      n,
   const Number*              x,
   const Number*              z_L,
   const Number*              z_U,
   Index                      m,
   const Number*              g,
   const Number*              lambda,
   Number                     obj_value,
   const IpoptData*           ip_data,
   IpoptCalculatedQuantities* ip_cq
)
{
   // here is where we would store the solution to variables, or write to a file, etc
   // so we could use the solution.

   /*
   // For this example, we write the solution to the console
   mexPrintf("\nSolution of the primal variables, x\n\n");
   for( Index i = 0; i < n; i++ ) {
      mexPrintf( "x[%d] = %f\n", i, x[i]);
   }
   
   mexPrintf("\nSolution of the bound multipliers, z_L and z_U\n");
   for( Index i = 0; i < n; i++ )
   {
      mexPrintf( "z_L[%d] = %f\n", i, z_L[i]);
   }
   for( Index i = 0; i < n; i++ )
   {
      std::cout << "z_U[" << i << "] = " << z_U[i] << std::endl;
   }

   std::cout << std::endl << std::endl << "Objective value" << std::endl;
   std::cout << "f(x*) = " << obj_value << std::endl;

   std::cout << std::endl << "Final value of the constraints:" << std::endl;
   for( Index i = 0; i < m; i++ )
   {
      std::cout << "g(" << i << ") = " << g[i] << std::endl;
   }
   */

   // store the solution
   solution = new double[n];
   for( Index i = 0; i < n; i++ ) {
      solution[i] = (double)x[i];
   }
}

#endif