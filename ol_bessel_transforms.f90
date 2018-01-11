! -*- mode: F90; mode: font-lock; column-number-mode: true; vc-back-end: CVS -*-
! ------------------------------------------------------------------------------
! $Id$
! ------------------------------------------------------------------------------
! Module bessel_integrals
! ------------------------------------------------------------------------------
! Code area 11: basis functions
! ------------------------------------------------------------------------------

!!****h* Conquest/bessel_integrals *
!!  NAME
!!   bessel_integrals
!!  PURPOSE
!!   Holds routines to calculate spherical Bessel transforms of data arrays.
!!   using mixture of FFT subroutines and radial integrals
!!   in real space (FFT's diverge near origin) to evaluate 
!!   spherical Bessel transforms of basis functions.
!!  AUTHOR
!!   R Choudhury
!!  CREATION DATE
!!   24/07/03
!!  MODIFICATION HISTORY
!!   2007/01/09 08:28 dave
!!    Tidying, incorporating changes from TM
!!   2007/08/15 12:04 dave
!!    Changed lmax_fact to 22 to accomodate f functions
!!   2008/02/06 08:28 dave
!!    Changed for output to file not stdout
!!  SOURCE
!!
module bessel_integrals

  use datatypes
  use global_module, ONLY: io_lun, area_basis

  implicit none

  ! -------------------------------------------------------
  ! RCS ident string for object file id
  ! -------------------------------------------------------
  character(len=80), private :: RCSid = "$Id$"

  !integer,parameter :: lmax_fact=22
  !real(double) :: fact(-1:lmax_fact)
  save
  
  real(double), allocatable, dimension(:) :: fact
  real(double), allocatable, dimension(:,:) :: bess_coeff

!!***
   
contains

!!****f* bessel_integrals/bess0_int *
!!
!!  NAME 
!!   bess0_int
!!  USAGE
!!   bess0_int(func,npts,npts_2,rcut,delta_r,func_out)
!!  PURPOSE
!!   Calculate 0th order spherical Bessel transform
!!  INPUTS
!!   func - input data array
!!   npts - no of non-zero data points in func
!!   npts_2 - total size of func, inc. padding up to 2^n
!!   rcut - cut off radius of func
!!   delta_r - grid spacing of func
!!   func_out - Bessel Transform output
!!  USES
!!   fft_procedures, datatypes
!!  AUTHOR
!!   R Choudhury
!!  CREATION DATE
!!   24/07/03
!!  MODIFICATION HISTORY
!!
!!  SOURCE
!!
  subroutine bess0_int(func,npts,npts_2,rcut,delta_r,func_out)
    
    use fft_procedures, only: sinft
    use datatypes
    use numbers, only: zero, twopi
    use GenComms, only: cq_abort
    use memory_module, only: reg_alloc_mem, reg_dealloc_mem, type_dbl

    implicit none

    !subroutine to evaluate integral against spherical 
    !Bessel function j_0(kr) using FFT's
    integer, intent(in) :: npts,npts_2
    real(double), intent(in), dimension(npts) :: func
    real(double), intent(out), dimension(npts_2/2) :: func_out
    real(double), intent(in) :: rcut, delta_r

    real(double), dimension(:), allocatable :: dummy1
    real(double) :: k,r,rcp_k,n
    integer :: i, stat

    allocate(dummy1(npts_2), STAT=stat)
    if (stat /= 0) call cq_abort("bess0_int: Error alloc mem: ", npts_2)
    call reg_alloc_mem(area_basis, npts_2, type_dbl)

    !assign different sin/cos component first..
    dummy1(1:npts_2)=zero
    do i=1,npts
       r = (i-1)*delta_r
       dummy1(i)=r*delta_r*func(i)
    enddo

    call sinft(dummy1,npts_2)

    do i=3,npts_2,2
       k = ((i-1)/2)*twopi/(rcut+delta_r)
       rcp_k = 1.0_double/k
       !phase shifting 
       func_out((i+1)/2) = rcp_k*dummy1(i)
    enddo
    !need to put in a quadrature here to evaluate 
    !the freq.=0 element of the output.
    func_out(1) = zero
    do i=1,npts
       r = (i-1)*delta_r
       func_out(1) = func_out(1)+(r*r*delta_r*func(i))
    enddo

    deallocate(dummy1, STAT=stat)
    if (stat /= 0) call cq_abort("bess0_int: Error dealloc mem")
    call reg_dealloc_mem(area_basis, npts_2, type_dbl)

  end subroutine bess0_int
!!***

!!****f* bessel_integrals/bess1_int *
!!
!!  NAME 
!!   bess1_int
!!  USAGE
!!   bess1_int(func,npts,npts_2,rcut,delta_r,func_out)
!!  PURPOSE
!!   Calculate 1st order spherical Bessel transform
!!  INPUTS
!!   func - input data array
!!   npts - no of non-zero data points in func
!!   npts_2 - total size of func, inc. padding up to 2^n
!!   rcut - cut off radius of func
!!   delta_r - grid spacing of func
!!   func_out - Bessel Transform output
!!  USES
!!   fft_procedures, datatypes
!!  AUTHOR
!!   R Choudhury
!!  CREATION DATE
!!   24/07/03
!!  MODIFICATION HISTORY
!!   08:59, 2003/11/13 dave
!!    Corrected dimension of func_out to npts_2/2 (TM found)
!!  SOURCE
!!
   subroutine bess1_int(func,npts,npts_2,rcut,delta_r,func_out)
  
     use datatypes
     use fft_procedures, ONLY: sinft,cosft
     use numbers, ONLY: zero, one, twopi
     use GenComms, ONLY: cq_abort
     use memory_module, ONLY: reg_alloc_mem, reg_dealloc_mem, type_dbl

     implicit none

     !subroutine to evaluate integral against spherical 
     !Bessel function j_1(kr) using FFT's

     integer, intent(in) :: npts,npts_2
     real(double), intent(in), dimension(npts) :: func
     real(double), intent(out), dimension(npts_2/2) :: func_out
     real(double), intent(in) :: rcut, delta_r

     real(double), dimension(:), allocatable :: dummy1, dummy2
     real(double) :: k,r,rcp_k,n,rcp_r
     integer :: i, stat

     allocate(dummy1(npts_2), dummy2(npts_2), STAT=stat)
     if (stat /= 0) call cq_abort("bess1_int: Error alloc mem: ", npts_2)
     call reg_alloc_mem(area_basis, 2*npts_2, type_dbl)

     !assign different sin/cos component first..
     dummy1 = zero
     dummy2 = zero
     do i=2,npts
        r = (i-1)*delta_r
        rcp_r = one/r
        dummy1(i) = delta_r*func(i)
        dummy2(i) = -delta_r*r*func(i)
     enddo

     call sinft(dummy1,npts_2)
     call cosft(dummy2,npts_2,+1)

     do i=3,npts_2,2
        k = ((i-1)/2)*twopi/(rcut+delta_r)
        rcp_k = one/k
        !phase shifting 
        func_out((i+1)/2) = rcp_k*(dummy2(i)+rcp_k*dummy1(i))
     enddo
     func_out(1) = zero

     deallocate(dummy1, dummy2, STAT=stat)
     if (stat /= 0) call cq_abort("bess1_int: Error dealloc mem")
     call reg_dealloc_mem(area_basis, 2*npts_2, type_dbl)

   end subroutine bess1_int
!!***

!!****f* bessel_integrals/bess2_int *
!!
!!  NAME 
!!   bess2_int
!!  USAGE
!!   bess2_int(func,npts,npts_2,rcut,delta_r,func_out)
!!  PURPOSE
!!   Calculate 2nd order spherical Bessel transform
!!  INPUTS
!!   func - input data array
!!   npts - no of non-zero data points in func
!!   npts_2 - total size of func, inc. padding up to 2^n
!!   rcut - cut off radius of func
!!   delta_r - grid spacing of func
!!   func_out - Bessel Transform output
!!  USES
!!   fft_procedures, datatypes
!!  AUTHOR
!!   R Choudhury
!!  CREATION DATE
!!   24/07/03
!!  MODIFICATION HISTORY
!!
!!  SOURCE
!!
   subroutine bess2_int(func,npts,npts_2,rcut,delta_r,func_out)

     use datatypes
     use fft_procedures, only : sinft,cosft
     use numbers, only: zero, one, three, twopi
     use GenComms, only: cq_abort
     use memory_module, only: reg_alloc_mem, reg_dealloc_mem, type_dbl

     implicit none

     !subroutine to evaluate integral against spherical 
     !Bessel function j_2(kr) using FFT's

     integer, intent(in) :: npts,npts_2
     real(double), intent(in), dimension(npts) :: func
     real(double), intent(out), dimension(npts_2/2) :: func_out
     real(double), intent(in) :: rcut, delta_r

     real(double), dimension(:), allocatable :: dummy1,dummy2,dummy3
     real(double) :: k,r,rcp_k,n,rcp_r
     integer :: i, stat

     allocate(dummy1(npts_2), dummy2(npts_2), dummy3(npts_2), STAT=stat)
     if (stat /= 0) call cq_abort("bess2_int: Error alloc mem: ", npts_2)
     call reg_alloc_mem(area_basis, 3*npts_2, type_dbl)

     !assign different sin/cos component first..
     dummy1 = zero
     dummy2 = zero
     dummy3 = zero
     do i=2,npts
        r = (i-1)*delta_r
        rcp_r = one/r
        dummy1(i) = three*delta_r*func(i)*rcp_r
        dummy2(i) = -three*delta_r*func(i)
        dummy3(i) = -one*delta_r*r*func(i)
     enddo

     call sinft(dummy1,npts_2)
     call cosft(dummy2,npts_2,+1)
     call sinft(dummy3,npts_2)

     do i=3,npts_2,2
        k = ((i-1)/2)*twopi/(rcut+delta_r)
        rcp_k = one/k
        !phase shifting
        func_out((i+1)/2) = rcp_k*(dummy3(i)+rcp_k* (dummy2(i)+rcp_k*dummy1(i)))
     enddo
     func_out(1) = zero

     deallocate(dummy1, dummy2, dummy3, STAT=stat)
     if (stat /= 0) call cq_abort("bess2_int: Error dealloc mem")
     call reg_dealloc_mem(area_basis, 3*npts_2, type_dbl)

   end subroutine bess2_int
!!***

!!****f* bessel_integrals/bess3_int *
!!
!!  NAME 
!!   bess3_int
!!  USAGE
!!   bess3_int(func,npts,npts_2,rcut,delta_r,func_out)
!!  PURPOSE
!!   Calculate 3th order spherical Bessel transform
!!  INPUTS
!!   func - input data array
!!   npts - no of non-zero data points in func
!!   npts_2 - total size of func, inc. padding up to 2^n
!!   rcut - cut off radius of func
!!   delta_r - grid spacing of func
!!   func_out - Bessel Transform output
!!  USES
!!   fft_procedures, datatypes
!!  AUTHOR
!!   R Choudhury
!!  CREATION DATE
!!   24/07/03
!!  MODIFICATION HISTORY
!!
!!  SOURCE
!!
   subroutine bess3_int(func,npts,npts_2,rcut,delta_r,func_out)

     use datatypes
     use fft_procedures, ONLY : sinft,cosft
     use numbers, ONLY: zero, one, six, twopi, fifteen
     use GenComms, ONLY: cq_abort
     use memory_module, ONLY: reg_alloc_mem, reg_dealloc_mem, type_dbl

     implicit none

     !subroutine to evaluate integral against spherical 
     !Bessel function j_3(kr) using FFT's

     integer, intent(in) :: npts,npts_2
     real(double), intent(in), dimension(npts) :: func
     real(double), intent(out), dimension(npts_2/2) :: func_out
     real(double), intent(in) :: rcut, delta_r

     real(double), dimension(:), allocatable :: dummy1,dummy2,dummy3,dummy4
     real(double) :: k,r,rcp_k,n,rcp_r
     integer :: i, stat

     allocate(dummy1(npts_2), dummy2(npts_2), dummy3(npts_2), &
              dummy4(npts_2), STAT=stat)
     if (stat /= 0) call cq_abort("bess3_int: Error alloc mem: ", npts_2)
     call reg_alloc_mem(area_basis, 4*npts_2, type_dbl)

     !assign different sin/cos component first..
     dummy1 = zero
     dummy2 = zero
     dummy3 = zero
     dummy4 = zero
     do i=2,npts
        r = (i-1)*delta_r
        rcp_r = one/r
        dummy1(i) = fifteen*delta_r*func(i)*rcp_r*rcp_r
        dummy2(i) = -fifteen*delta_r*func(i)*rcp_r
        dummy3(i) = -six*delta_r*func(i)
        dummy4(i) = r*delta_r*func(i)
     enddo

     call sinft(dummy1,npts_2)
     call cosft(dummy2,npts_2,+1)
     call sinft(dummy3,npts_2)
     call cosft(dummy4,npts_2,+1)

     do i=3,npts,2
        k = ((i-1)/2)*twopi/(rcut+delta_r)
        rcp_k = one/k
        !phase shift
        func_out((i+1)/2) = rcp_k*(dummy4(i)+rcp_k*(dummy3(i)+rcp_k* (dummy2(i)+rcp_k*dummy1(i))))
     enddo
     func_out(1) = zero

     deallocate(dummy1, dummy2, dummy3, dummy4, STAT=stat)
     if (stat /= 0) call cq_abort("bess3_int: Error dealloc mem")
     call reg_dealloc_mem(area_basis, 4*npts_2, type_dbl)

   end subroutine bess3_int
!!***

!!****f* bessel_integrals/bess4_int *
!!
!!  NAME 
!!   bess4_int
!!  USAGE
!!   bess4_int(func,npts,npts_2,rcut,delta_r,func_out)
!!  PURPOSE
!!   Calculate 4th order spherical Bessel transform
!!  INPUTS
!!   func - input data array
!!   npts - no of non-zero data points in func
!!   npts_2 - total size of func, inc. padding up to 2^n
!!   rcut - cut off radius of func
!!   delta_r - grid spacing of func
!!   func_out - Bessel Transform output
!!  USES
!!   fft_procedures, datatypes
!!  AUTHOR
!!   R Choudhury
!!  CREATION DATE
!!   24/07/03
!!  MODIFICATION HISTORY
!!
!!  SOURCE
!!
   subroutine bess4_int(func,npts,npts_2,rcut,delta_r,func_out)

     use fft_procedures, ONLY : sinft,cosft
     use datatypes
     use numbers, ONLY: zero, one, twopi
     use GenComms, ONLY: cq_abort
     use memory_module, ONLY: reg_alloc_mem, reg_dealloc_mem, type_dbl

     implicit none

     !subroutine to evaluate integral against spherical 
     !Bessel function j_4(kr) using FFT's
     integer, intent(in) :: npts,npts_2
     real(double), intent(in), dimension(npts) :: func
     real(double), intent(out), dimension(npts_2/2) :: func_out
     real(double), intent(in) :: rcut, delta_r

     real(double), dimension(:), allocatable :: dummy1, dummy2, &
                                                dummy3, dummy4, dummy5
     real(double) :: k,r,rcp_k,n,rcp_r
     integer :: i, stat

     allocate(dummy1(npts_2), dummy2(npts_2), dummy3(npts_2), &
              dummy4(npts_2), dummy5(npts_2), STAT=stat)
     if (stat /= 0) call cq_abort("bess4_int: Error alloc mem: ", npts_2)
     call reg_alloc_mem(area_basis, 5*npts_2, type_dbl)

     !assign different sin/cos component first..
     dummy1 = zero
     dummy2 = zero
     dummy3 = zero
     dummy4 = zero
     dummy5 = zero
     do i=2,npts
        r = (i-1)*delta_r
        rcp_r = one/r
        dummy1(i) =  105.0_double*delta_r*func(i)*rcp_r*rcp_r*rcp_r
        dummy2(i) = -105.0_double*delta_r*func(i)*rcp_r*rcp_r
        dummy3(i) =  -45.0_double*delta_r*func(i)*rcp_r
        dummy4(i) =   10.0_double*delta_r*func(i)
        dummy5(i) = delta_r*r*func(i)
     enddo

     call sinft(dummy1,npts_2)
     call cosft(dummy2,npts_2,+1)
     call sinft(dummy3,npts_2)
     call cosft(dummy4,npts_2,+1)
     call sinft(dummy5,npts_2)

     do i=3,npts,2
        k = ((i-1)/2)*twopi/(rcut+delta_r)
        rcp_k = one/k
        !phase shifting
        func_out((i+1)/2) = rcp_k*(dummy5(i)+rcp_k*&
             &(dummy4(i)+rcp_k*(dummy3(i)+rcp_k* (dummy2(i)+rcp_k*dummy1(i)))))
     enddo
     func_out(1) = zero

     deallocate(dummy1, dummy2, dummy3, dummy4, dummy5, STAT=stat)
     if (stat /= 0) call cq_abort("bess4_int: Error dealloc mem")
     call reg_dealloc_mem(area_basis, 5*npts_2, type_dbl)

   end subroutine bess4_int
!!***

!!****f* bessel_integrals/bess5_int *
!!
!!  NAME 
!!   bess5_int
!!  USAGE
!!   bess5_int(func,npts,npts_2,rcut,delta_r,func_out)
!!  PURPOSE
!!   Calculate 5th order spherical Bessel transform
!!  INPUTS
!!   func - input data array
!!   npts - no of non-zero data points in func
!!   npts_2 - total size of func, inc. padding up to 2^n
!!   rcut - cut off radius of func
!!   delta_r - grid spacing of func
!!   func_out - Bessel Transform output
!!  USES
!!   fft_procedures, datatypes
!!  AUTHOR
!!   R Choudhury
!!  CREATION DATE
!!   24/07/03
!!  MODIFICATION HISTORY
!!
!!  SOURCE
!!    
   subroutine bess5_int(func,npts,npts_2,rcut,delta_r,func_out)

     use fft_procedures, ONLY : sinft,cosft
     use datatypes
     use numbers, ONLY: zero, one, twopi, fifteen
     use GenComms, ONLY: cq_abort
     use memory_module, ONLY: reg_alloc_mem, reg_dealloc_mem, type_dbl

     implicit none

     !subroutine to evaluate integral against spherical 
     !Bessel function j_5(kr) using FFT's
     !integer, parameter :: dp = selected_real_kind(p=14,r=30)
     integer, intent(in) :: npts,npts_2
     real(double), intent(in), dimension(npts) :: func
     real(double), intent(out), dimension(npts_2/2) :: func_out
     real(double), intent(in) :: rcut, delta_r

     real(double), dimension(:), allocatable :: dummy1, dummy2, &
                                                dummy3, dummy4, &
                                                dummy5, dummy6
     real(double) :: k,r,rcp_k,n,rcp_r,int_part,bess5,rcp_kr,kr
     integer :: i, j, stat

     allocate(dummy1(npts_2), dummy2(npts_2), dummy3(npts_2), &
              dummy4(npts_2), dummy5(npts_2), dummy6(npts_2), STAT=stat)
     if (stat /= 0) call cq_abort("bess5_int: Error alloc mem: ", npts_2)
     call reg_alloc_mem(area_basis, 6*npts_2, type_dbl)

     !assign different sin/cos component first..
     dummy1 = zero
     dummy2 = zero
     dummy3 = zero
     dummy4 = zero
     dummy5 = zero
     dummy6 = zero
     do i=2,npts
        r = (i-1)*delta_r
        rcp_r = one/r
        dummy1(i) =  945.0_double*delta_r*func(i)*rcp_r*rcp_r*rcp_r*rcp_r
        dummy2(i) = -945.0_double*delta_r*func(i)*rcp_r*rcp_r*rcp_r
        dummy3(i) = -420.0_double*delta_r*func(i)*rcp_r*rcp_r
        dummy4(i) =  105.0_double*delta_r*func(i)*rcp_r
        dummy5(i) =       fifteen*delta_r*func(i)
        dummy6(i) =          -one*delta_r*func(i)*r
     enddo

     call sinft(dummy1,npts_2)
     call cosft(dummy2,npts_2,+1)
     call sinft(dummy3,npts_2)
     call cosft(dummy4,npts_2,+1)
     call sinft(dummy5,npts_2)
     call cosft(dummy6,npts_2,+1)


     !added option for real space quadrature of overlap integral
     !for small values of k as the FFT transforms diverge.
     do i=3,npts_2,2
        k = ((i-1)/2)*twopi/(rcut+delta_r)

        if(k<0.2_double) then
           int_part = zero
           do j=1,npts-1
              r = j*delta_r
              kr = r*k
              rcp_kr = one/kr
              if(kr<0.01_double) then
                 bess5 = bess5_ser(kr)
              else
                 bess5 = rcp_kr*(-1.0_double*cos(kr)+rcp_kr*(15.0_double*sin(kr)&
                      &+rcp_kr*(105.0_double*cos(kr)+rcp_kr*(-420.0_double*sin(kr)&
                      &+rcp_kr*(-945.0_double*cos(kr)+945.0_double*sin(kr)*rcp_kr)))))
              endif
              int_part = int_part+bess5*delta_r*r*r*func(j+1)
           enddo
           func_out((i-1)/2) = int_part
        else
           rcp_k = one/k
           func_out((i-1)/2) = rcp_k*(dummy6(i)+rcp_k*&
                &(dummy5(i)+rcp_k*(dummy4(i)+rcp_k*(dummy3(i)+rcp_k*&
                &(dummy2(i)+rcp_k*dummy1(i))))))
        endif
     enddo
     func_out(1) = zero

     deallocate(dummy1, dummy2, dummy3, dummy4, dummy5, dummy6, STAT=stat)
     if (stat /= 0) call cq_abort("bess5_int: Error dealloc mem")
     call reg_dealloc_mem(area_basis, 6*npts_2, type_dbl)

   end subroutine bess5_int
!!***

!!****f* bessel_integrals/bess6_int *
!!
!!  NAME 
!!   bess6_int
!!  USAGE
!!   bess6_int(func,npts,npts_2,rcut,delta_r,func_out)
!!  PURPOSE
!!   Calculate 6th order spherical Bessel transform
!!  INPUTS
!!   func - input data array
!!   npts - no of non-zero data points in func
!!   npts_2 - total size of func, inc. padding up to 2^n
!!   rcut - cut off radius of func
!!   delta_r - grid spacing of func
!!   func_out - Bessel Transform output
!!  USES
!!   fft_procedures, datatypes
!!  AUTHOR
!!   R Choudhury
!!  CREATION DATE
!!   24/07/03
!!  MODIFICATION HISTORY
!!
!!  SOURCE
!!
   subroutine bess6_int(func,npts,npts_2,rcut,delta_r,func_out)

     use fft_procedures, ONLY : sinft,cosft
     use datatypes
     use numbers, ONLY: zero, one, twopi
     use GenComms, ONLY: cq_abort
     use memory_module, ONLY: reg_alloc_mem, reg_dealloc_mem, type_dbl

     implicit none

     !subroutine to evaluate integral against spherical 
     !Bessel function j_6(kr) using FFT's
     integer, intent(in) :: npts,npts_2
     real(double), intent(in), dimension(npts) :: func
     real(double), intent(out), dimension(npts_2/2) :: func_out
     real(double), intent(in) :: rcut, delta_r

     real(double), dimension(:), allocatable :: dummy1, dummy2, &
                                                dummy3, dummy4, &
                                                dummy5, dummy6, &
                                                dummy7        
     real(double) :: k,r,rcp_k,n,rcp_r,bess6,kr,rcp_kr,int_part
     integer :: i, j, stat

     allocate(dummy1(npts_2), dummy2(npts_2), dummy3(npts_2), &
              dummy4(npts_2), dummy5(npts_2), dummy6(npts_2), &
              dummy7(npts_2), STAT=stat)
     if (stat /= 0) call cq_abort("bess6_int: Error alloc mem: ", npts_2)
     call reg_alloc_mem(area_basis, 7*npts_2, type_dbl)

     !assign different sin/cos component first..
     dummy1 = zero
     dummy2 = zero
     dummy3 = zero
     dummy4 = zero
     dummy5 = zero
     dummy6 = zero
     dummy7 = zero
     do i=2,npts
        r = (i-1)*delta_r
        rcp_r = one/r
        dummy1(i) =  10395.0_double*delta_r*func(i)*rcp_r*rcp_r*rcp_r*rcp_r*rcp_r
        dummy2(i) = -10395.0_double*delta_r*func(i)*rcp_r*rcp_r*rcp_r*rcp_r
        dummy3(i) =  -4725.0_double*delta_r*func(i)*rcp_r*rcp_r*rcp_r
        dummy4(i) =   1260.0_double*delta_r*func(i)*rcp_r*rcp_r
        dummy5(i) =    210.0_double*delta_r*func(i)*rcp_r
        dummy6(i) =    -21.0_double*delta_r*func(i)
        dummy7(i) =            -one*delta_r*func(i)*r
     enddo

     call sinft(dummy1,npts_2)
     call cosft(dummy2,npts_2,+1)
     call sinft(dummy3,npts_2)
     call cosft(dummy4,npts_2,+1)
     call sinft(dummy5,npts_2)
     call cosft(dummy6,npts_2,+1)
     call sinft(dummy7,npts_2)

     !added option for real-space quadrature of radial integrals as
     !the FFT intgrals diverge for very small values of k.
     do i=3,npts_2,2
        k = ((i-1)/2)*twopi/(rcut+delta_r)
        if(k<0.2_double) then
           int_part = zero
           do j=1,npts-1
              r = j*delta_r
              kr = k*r
              rcp_kr = one/kr
              if(kr<0.02_double) then
                 bess6 = bess6_ser(kr)
              else
                 bess6 = rcp_kr*(-1.0_double*sin(kr)+rcp_kr*(-21.0_double*cos(kr)&
                      &+rcp_kr*(210.0_double*sin(kr)+rcp_kr*(1260.0_double*cos(kr)&
                      &+rcp_kr*(-4725.0_double*sin(kr)+rcp_kr*(-10395.0_double*cos(kr)&
                      &+rcp_kr*10395.0_double*sin(kr)))))))
              endif
              int_part = int_part+bess6*delta_r*r*r*func(j+1)
           enddo
           func_out((i-1)/2) = int_part
        else


           rcp_k = 1.0_double/k
           func_out((i-1)/2) = rcp_k*(dummy7(i)+rcp_k*&
                &(dummy6(i)+rcp_k*(dummy5(i)+rcp_k*(dummy4(i)&
                &+rcp_k*(dummy3(i)+rcp_k*&
                &(dummy2(i)+rcp_k*dummy1(i)))))))
        endif
     enddo
     func_out(1) = zero

     deallocate(dummy1, dummy2, dummy3, dummy4, dummy5, dummy6, &
                dummy7, STAT=stat)
     if (stat /= 0) call cq_abort("bess6_int: Error dealloc mem")
     call reg_dealloc_mem(area_basis, 7*npts_2, type_dbl)

   end subroutine bess6_int
!!***

!!****f* bessel_integrals/bessloop *
!!
!!  NAME 
!!   bessloop
!!  USAGE
!!   bessloop(dummyin,l,npts,npts_2,deltar,rcut,dummyout)
!!  PURPOSE
!!   Choose Bessel Transform subroutine that matches l-value of input array
!!  INPUTS
!!   dummyin : input dat array
!!   l : angular momentum of input data array
!!   npts : actual data points in dummyin
!!   npts_2 : no of actual+padded data points (= 2^n)
!!   deltar : grid spacing of data points
!!   rcut : real space cut off of dummyin(npts_2)
!!   dummyout : bessel transform of original data 
!!  USES
!!   datatypes
!!  AUTHOR
!!   R Choudhury
!!  CREATION DATE
!!   24/07/03
!!  MODIFICATION HISTORY
!!   2007/01/09 08:09 dave
!!    Dimension of dummyout fixed
!!  SOURCE
!!
   subroutine bessloop(dummyin,l,npts,npts_2,deltar,rcut,dummyout,sign)

     use datatypes

     implicit none

     !choosing spherical Bessel transform subroutine 
     !for incoming angular momentum value l
     integer, intent(in) :: l,npts,npts_2,sign
     real(double), intent(in), dimension(npts) :: dummyin
     real(double), intent(out), dimension(npts_2/2) :: dummyout 
     real(double), intent(in) :: deltar,rcut

     !if(.true.) then
     !   call general_bess_int(l,dummyin,npts,npts_2,rcut,deltar,dummyout,sign)
     !   return
     !end if

     
     !if clause to select correct subroutine
     if(l.eq.0) then
        !write(io_lun,*) 'bessloop l=0'
        !RC for debugging purposes
        !call bess0_int_test(dummyin,npts,npts_2,rcut,deltar,dummyout)
        call bess0_int(dummyin,npts,npts_2,rcut,deltar,dummyout)
     else if(l.eq.1) then
        !write(io_lun,*) 'bessloop l=1'
        call bess1_int(dummyin,npts,npts_2,rcut,deltar,dummyout)
     else if(l.eq.2) then
        !write(io_lun,*) 'bessloop l=2'
        call bess2_int(dummyin,npts,npts_2,rcut,deltar,dummyout)
     else if(l.eq.3) then 
        !write(io_lun,*) 'bessloop l=3'
        call bess3_int(dummyin,npts,npts_2,rcut,deltar,dummyout)
     else if(l.eq.4) then
        !write(io_lun,*) 'bessloop l=4'
        call bess4_int(dummyin,npts,npts_2,rcut,deltar,dummyout)
     else if(l.eq.5) then
        !write(io_lun,*) 'bessloop l=5'
        call bess5_int(dummyin,npts,npts_2,rcut,deltar,dummyout)
     else if(l.eq.6) then
        !write(io_lun,*) 'bessloop l=6'
        call bess6_int(dummyin,npts,npts_2,rcut,deltar,dummyout)
     else 
        write(io_lun,*) 'steady on, this value of the total&
             &angular momentum has made me dizzy!'
     endif

   end subroutine bessloop
!!***

!!****f* bessel_integrals/twon *
!!
!!  NAME 
!!   twon
!!  USAGE
!!   twon(npts,npts_2)
!!  PURPOSE
!!   Calculate next highest no to npts which is an integer power of 2
!!  INPUTS
!!   npts : original no of points
!!   npts_2 : padded up to 2^n no of points
!!  USES
!!   none
!!  AUTHOR
!!   R Choudhury
!!  CREATION DATE
!!   24/07/03
!!  MODIFICATION HISTORY
!!
!!  SOURCE
!!
   subroutine twon(npts,npts_2)
     implicit none

     integer, intent(in) :: npts
     integer, intent(out) :: npts_2
     integer :: i

     do i=1,30
        if(npts.lt.2**i) then
           npts_2=2**i
           exit ! Leave do loop
        endif
     enddo
   end subroutine twon
!!***

!!****f* bessel_integrals/complx_fctr *
!!
!!  NAME 
!!   complx_fctr
!!  USAGE
!!   complx_fctr(l1,l2,l,factor)
!!  PURPOSE
!!   calculate real prefactors for radial tables
!!  INPUTS
!!   l1,l2,l - angular momentum values of triplets in radial table
!!   factor : real prefactor output
!!  USES
!!   none
!!  AUTHOR
!!   R Choudhury
!!  CREATION DATE
!!   24/07/03
!!  MODIFICATION HISTORY
!!
!!  SOURCE
!!
   subroutine complx_fctr(l1,l2,l,factor)

     use datatypes 
     use numbers, ONLY: zero, one

     implicit none

     complex(double_cplx) :: z1,factor1
     real(double), intent(out) :: factor
     integer, intent(in) :: l1,l2,l

     z1 = cmplx(zero,one,double_cplx)

     factor1 = (z1**l1)*(conjg(z1**l2))*(conjg(z1**l))
     factor = factor1-aimag(factor1)
     !write(io_lun,*) factor1,'factor1',factor,'factor'

   end subroutine complx_fctr
!!***

!!****f* bessel_integrals/maxtwon *
!!
!!  NAME 
!!   maxtwon
!!  USAGE
!!   maxtwon(n1,del1,n2,del2,n12,del12,delk,kcut)
!!  PURPOSE
!!   Calculate size of array required for spherical Bessel transforms
!!  INPUTS
!!   n1,n2 : sizes of input arrays 
!!   del1, del2 : grid spacing of original arrays
!!   n12, del12 : size and grid spacing of required arrays
!!   delk, kcut : k space grid spacing and cut-off
!!  USES
!!   datatypes
!!  AUTHOR
!!   R Choudhury
!!  CREATION DATE
!!   24/07/03
!!  MODIFICATION HISTORY
!!
!!  SOURCE
!!
   subroutine maxtwon(n1,del1,n2,del2,n12,del12,delk,kcut)

     use datatypes
     use numbers, ONLY: two, twopi

     implicit none
     !code to get upper bound on size of the two
     !arrays as integral power of 2
     real(double),intent(in):: del1,del2,delk,kcut
     real(double), intent(inout) :: del12
     integer n1,n2,n12,s1,s2,n1_max,n2_max,s3,s3_max

     !choosing according to restrictions (of user)
     !on minimum delk, min kcut...
     del12 = twopi/(two*kcut)
     s3 = two*(kcut)/delk
     call twon(s3,s3_max)
     n12 = s3_max

   end subroutine maxtwon
!!***

!!****f* bessel_integrals/multiply_ksq *
!!
!!  NAME 
!!   multiply_ksq
!!  USAGE
!!   multiply_ksq(y,n,dk)
!!  PURPOSE
!!   Multiply input array by k squared
!!  INPUTS
!!   y : input data array
!!   n : no of points in input array
!!   dk : grid spacing of input array
!!  USES
!!   datatypes
!!  AUTHOR
!!   R Choudhury
!!  CREATION DATE
!!   24/07/03
!!  MODIFICATION HISTORY
!!
!!  SOURCE
!!
   subroutine multiply_ksq(y,n,dk)

     use datatypes

     implicit none

     integer, intent(in) :: n
     real(double),intent(inout), dimension(n) :: y
     real(double), intent(in) ::dk
     real(double) :: k
     integer i
     
     do i=1,n
        k = (i-1)*dk
        y(i) = k*k*y(i)
     enddo

   end subroutine multiply_ksq
!!***
        
!!****f* bessel_integrals/bess5_ser *
!!
!!  NAME 
!!   bess5_ser
!!  USAGE
!!   bess5_ser(x)
!!  PURPOSE
!!   Calculate 5th order spherical Bessel function with small
!!   argument x using small argument expansion. 
!!  INPUTS
!!   x : argument
!! 
!!  USES
!!   none
!!  AUTHOR
!!   R Choudhury
!!  CREATION DATE
!!   24/07/03
!!  MODIFICATION HISTORY
!!
!!  SOURCE
!!
   function bess5_ser(x)

     use datatypes
     use numbers, ONLY: zero,two
     implicit none

     integer :: s
     real(double) :: bess5_ser
     real(double) :: bess5_part
     real(double), intent(in) :: x

     bess5_part = zero
     bess5_ser = zero

     do s=0,4
        bess5_part = ((-1)**s)*fact(s+5)*(x**(2*s)) /(fact(s)*fact(2*s+11))
        bess5_ser = bess5_ser + bess5_part
     enddo

     bess5_ser = bess5_ser*two*two*two*two*two*x*x*x*x*x

   end function bess5_ser
!!***
    
!!****f* bessel_integrals/bess6_ser *
!!
!!  NAME 
!!   bess6_ser
!!  USAGE
!!   bess6_ser(x)
!!  PURPOSE
!!   Calculate 6th spherical Bessel function with (small) argument x
!!  INPUTS
!!   x : small argument
!! 
!!  USES
!!   none
!!  AUTHOR
!!   R Choudhury
!!  CREATION DATE
!!   24/07/03
!!  MODIFICATION HISTORY
!!
!!  SOURCE
!!
   function bess6_ser(x)
     use datatypes
     implicit none
     !j_6(x) series approximation
     integer s
     real(double) :: bess6_ser
     real(double) :: bess6_part
     real(double), intent(in) :: x

     bess6_part = 0.0_double
     bess6_ser = 0.0_double

     do s=0,4
        bess6_part = ((-1)**s)*fact(s+6)*(x**(2*s)) /(fact(s)*fact(2*s+13))
        bess6_ser = bess6_ser + bess6_part
     enddo

     bess6_ser = bess6_ser*2.0*2.0*2.0&
          &*2.0*x*x*x*x&
          &*2.0*x*2.0*x

   end function bess6_ser
!!***

   subroutine enum_bess_int(n)

     use datatypes
     use numbers, only: zero

     implicit none

     integer :: n

     type bess_expand
        integer :: n
        ! term is 0 or 1 for j0 or j1
        ! power is power of x scaling the term
        ! coeff is the coefficient
        integer, allocatable, dimension(:) :: term, power
        real(double), allocatable, dimension(:) :: coeff
     end type bess_expand

     integer :: i,j,k, fibn, fibn1,tmp,i_acc
     type(bess_expand), dimension(0:n) :: store

     allocate(bess_coeff(n+1,0:n))
     bess_coeff = zero
     do i=0,n
        if(i<2) then
           fibn = 1
        else
           fibn = 1
           fibn1 = 1
           do j= 2,i
              tmp = fibn
              fibn = fibn + fibn1
              fibn1 = tmp
           end do
        end if
        allocate(store(i)%term(fibn),store(i)%power(fibn),store(i)%coeff(fibn))
        !write(*,*) 'With i ',i,' we have ',fibn,' terms'
        store(i)%n = fibn
        if(i==0) then
           ! j0
           store(i)%term(1) = 0
           store(i)%power(1) = 0
           store(i)%coeff(1) = 1
        else if(i==1) then
           ! j1 only
           store(i)%term(1) = 1
           store(i)%power(1) = 0
           store(i)%coeff(1) = 1
        else ! Recurse using j_n = -j_{n-2} + (2n-1)j_{n-1}/x
           ! Term 1: -j_{n-2}
           do k=1,store(i-2)%n
              store(i)%term(k) = store(i-2)%term(k)
              store(i)%power(k) = store(i-2)%power(k)
              store(i)%coeff(k) = -store(i-2)%coeff(k)
           end do
           i_acc = store(i-2)%n
           ! Term 2: (2n-1)/x j_{n-1}
           tmp = 2*(i-1)+1
           do k=1,store(i-1)%n
              store(i)%term(i_acc+k) = store(i-1)%term(k)
              store(i)%power(i_acc+k) = store(i-1)%power(k)-1
              store(i)%coeff(i_acc+k) = store(i-1)%coeff(k)*tmp
           end do
        end if
        !write(*,fmt='(3x,"  Term Power Coeff")')
        !do k=1,store(i)%n
        !   write(*,fmt='(i3,3i6)') k,store(i)%term(k),store(i)%power(k),store(i)%coeff(k)
        !end do
        !write(*,*) 'Maximum power: ',i+1
        !allocate(coeff_sin(i+1),coeff_cos(i+1))
        bess_coeff(:,i) = zero
        !coeff_sin = 0
        !coeff_cos = 0
        do k=store(i)%n,1,-1
           if(store(i)%term(k)==0) then ! j0
              ! sin
              j=-store(i)%power(k)+1
              bess_coeff(j,i) = bess_coeff(j,i)+store(i)%coeff(k)
           else if(store(i)%term(k)==1) then ! j1 = sin/x^2 - cos/x
              ! cos
              j=-store(i)%power(k)+1
              bess_coeff(j,i) = bess_coeff(j,i)-store(i)%coeff(k)
              ! sin
              j=-store(i)%power(k)+2
              bess_coeff(j,i) = bess_coeff(j,i)+store(i)%coeff(k)
           end if
        end do
        !write(*,*) 'sin: ',coeff_sin
        !write(*,*) 'cos: ',coeff_cos
        !deallocate(coeff_sin,coeff_cos)
        !write(*,*) i,' Bessel coeff: ',bess_coeff(:,i)
     end do
   end subroutine enum_bess_int     

   subroutine general_bess_int(n,func,npts,npts_2,rcut,delta_r,func_out,sign)

     use fft_procedures, ONLY : sinft,cosft,realft,four1
     use datatypes
     use numbers, ONLY: zero, one, twopi, two
     use GenComms, ONLY: cq_abort
     use memory_module, ONLY: reg_alloc_mem, reg_dealloc_mem, type_dbl

     implicit none

     integer, intent(in) :: n,npts,npts_2,sign
     !integer, intent(in) :: n,npts,npts_2
     real(double), intent(in), dimension(npts) :: func
     real(double), intent(out), dimension(npts_2/2) :: func_out
     !real(double), intent(out), dimension(npts_2) :: func_out
     real(double), intent(in) :: rcut, delta_r

     real(double), dimension(:,:), allocatable :: dummy        
     !real(double), dimension(:), allocatable :: dummy        
     real(double) :: k,r,rcp_k,rcp_r,bess_ser,kr,rcp_kr,int_part,cumul,a,b
     integer :: i, j, stat, flip,s,t,low

     !write(20,*) 'On entry, ',npts_2,sign,n
     !%%! allocate(dummy(npts_2), STAT=stat)
     !%%! dummy = zero
     !%%! do i=1,npts
     !%%!    r = real((i-1),double)*delta_r
     !%%!    dummy(i) = general_bessel(r,n)*func(i)*r*r
     !%%!    !if(i<4) write(20,*) r,dummy(i)
     !%%! end do
     !%%! call realft(dummy,npts_2/2,sign)
     !%%! !do i=3,npts_2,2
     !%%! !func_out((i+1)/2) = dummy(i)
     !%%! func_out = dummy
     !%%! !end do
     !%%! !func_out(1) = zero
     !%%! !if(n==0) then
     !%%! !   do i=1,npts
     !%%! !      r = (i-1)*delta_r
     !%%! !      func_out(1) = func_out(1)+(r*r*delta_r*func(i))
     !%%! !   enddo
     !%%! !end if
     !%%! if(sign==-1) func_out = func_out/real(npts_2/2,double)
     !%%! deallocate(dummy, STAT=stat)
     !%%! return
     
     allocate(dummy(npts_2,n+1), STAT=stat)
     if (stat /= 0) call cq_abort("bess6_int: Error alloc mem: ", npts_2)
     call reg_alloc_mem(area_basis, (n+1)*npts_2, type_dbl)
     
     !write(*,*) 'Coeffs: ',bess_coeff(1:n+1,n)
     ! Initialise dummy array: remember that the index gives NEGATIVE power of r
     dummy = zero
     do j=1,n+1
        !dummy(1:npts,j) = bess_coeff(j,n)*delta_r
        dummy(1:npts,j) = delta_r
     end do
     ! Create terms in f(r).j_n(r).r^2 expansion
     low = 2
     if(n==0) then
        low = 1
     else
        dummy(1,:) = zero
     end if
     rcp_r = one
     do i=low,npts
        r = (i-1)*delta_r
        if(n>0.AND.i>1) rcp_r = one/r
        if(sign==1) then
           cumul = r**(n+1)*func(i)
        else !if(sign==0)
           cumul = r*func(i)
        end if
        do j=1,n+1
           dummy(i,j) = dummy(i,j)*cumul !*func(i)*cumul
           cumul = cumul*rcp_r
           !if(i<5) write(20,*) r,dummy(i,j),func(i),cumul
        end do
        !if(dummy(i,n+1)>1.0_double) dummy(i,:)=zero
        !if(n>5.AND.r<0.01_double) dummy(i,:)=zero
        !if(n>6.AND.r<0.2_double) dummy(i,:)=zero
        !if(n>6.AND.r<0.2_double) dummy(i,:)=zero
        !if(sign==0.AND.n>4.AND.r<0.1_double) dummy(i,:)=zero
        !if(sign==0.AND.n>4.AND.dummy(i,n+1)>10.0_double) dummy(i,:)=zero
     enddo
     ! Now perform sin/cos transforms
     do j=n+1,1,-2
        call sinft(dummy(:,j),npts_2)
     end do
     if(n>0) then
        do j=n,1,-2
           call cosft(dummy(:,j),npts_2,+1)
        end do
     end if
     
     !added option for real-space quadrature of radial integrals as
     !the FFT intgrals diverge for very small values of k.
     do i=3,npts_2,2
        k = ((i-1)/2)*twopi/(rcut+delta_r)
        if(n>1.AND.k<5.0_double) then
        !if(n>4.AND.k<0.5_double) then
           int_part = zero
           do j=1,npts-1
              r = real(j,double)*delta_r
              kr = k*r
              rcp_kr = one/kr
              if(sign==1) then
                 bess_ser = r**n*general_bessel(kr,n)!bess6_ser(kr)
              else
                 bess_ser = general_bessel(kr,n)
              end if
              int_part = int_part+bess_ser*delta_r*r*r*func(j+1)
           enddo
           func_out((i+1)/2) = int_part
        else
           rcp_k = 1.0_double/k
           func_out((i+1)/2) = rcp_k*dummy(i,n+1)*bess_coeff(n+1,n)
           !write(20+n,*) k,dummy(i,n+1)
           if(n>0) then
              do j=n,1,-1
                 func_out((i+1)/2) = rcp_k*(func_out((i+1)/2) + bess_coeff(j,n)*dummy(i,j))
                 !write(20+n+j,*) k,dummy(i,j)
              end do
           end if
        endif
     enddo
     func_out(1) = zero
     if(n==0) then
        do i=1,npts
           r = (i-1)*delta_r
           func_out(1) = func_out(1)+(r*r*delta_r*func(i))
        enddo
     end if
     deallocate(dummy, STAT=stat)
     if (stat /= 0) call cq_abort("bess6_int: Error dealloc mem")
     call reg_dealloc_mem(area_basis, (n+1)*npts_2, type_dbl)

   end subroutine general_bess_int

   function general_bessel(r,n)

     use datatypes
     use numbers
     use GenComms, only: cq_abort
     
     implicit none

     real(double) :: general_bessel
     ! Passed
     real(double) :: r
     integer :: n
     
     ! Local
     real(double), dimension(0:n) :: sph_bess
     integer :: i, s
     real(double) :: term
     logical :: flag_series

     flag_series = .false.
     if(n>2.AND.r<0.02_double) flag_series = .true.
     if(n>3.AND.r<0.1_double) flag_series = .true.
     if(n>4.AND.r<0.2_double) flag_series = .true.
     if(n>5.AND.r<0.4_double) flag_series = .true.
     if(n>6.AND.r<0.6_double) flag_series = .true.
     if(n>7.AND.r<0.9_double) flag_series = .true.
     if(n>8.AND.r<1.3_double) flag_series = .true.
     if(n>9.AND.r<1.8_double) flag_series = .true.
     if(n>10.AND.r<2.4_double) flag_series = .true.
     if(n<0) call cq_abort("Error: Can't have spherical bessel with order less than zero ",n)
     if(abs(r)<1e-8_double) then
        if(n>0) then
           general_bessel = zero
        else
           general_bessel = one - r*r/six ! Yes, I know... This is temporary !
        end if
     else if(flag_series) then
        general_bessel = zero
        do s=0,5
           term = ((-1)**s)*fact(s+n)*(r**(2*s)) /(fact(s)*fact(2*s+2*n+1))
           general_bessel = general_bessel + term
        enddo
        do i=1,n
           general_bessel = general_bessel * two * r
        end do
     else
        sph_bess(0) = sin(r)/r
        if(n==0) then
           general_bessel = sph_bess(0)
        else
           sph_bess(1) = (sph_bess(0) - cos(r))/r
           if(n==1) then
              general_bessel = sph_bess(1)
           else
              do i=2,n
                 sph_bess(i) = sph_bess(i-1)*real(2*i-1,double)/r - sph_bess(i-2)
              end do
              general_bessel = sph_bess(n)
           end if
        end if
     end if
   end function general_bessel
   
   
 end module bessel_integrals
