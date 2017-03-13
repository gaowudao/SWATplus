      subroutine res_elements_read
   
      use input_file_module
      use jrw_datalib_module
      use hydrograph_module
      use reservoir_module

      character (len=80) :: titldum, header
      integer :: eof
      
      imax = 0
      mcal = 0
            
    inquire (file=in_regs%def_res, exist=i_exist)
    if (i_exist /= 0 .or. in_regs%def_res /= 'null') then
      do
        open (107,file=in_regs%def_res)
        read (107,*,iostat=eof) titldum
        if (eof < 0) exit
        read (107,*,iostat=eof) mreg
        if (eof < 0) exit
        read (107,*,iostat=eof) header
        
        !allocate subbasin (landscape unit) outputs
        !allocate (reg_aqu_d(0:mreg)); allocate (reg_aqu_m(0:mreg)); allocate (reg_aqu_y(0:mreg)); allocate (reg_aqu_a(0:mreg))

      do i = 1, mreg

        read (107,*,iostat=eof) k, rcu_out(i)%name, rcu_out(i)%area_ha, nspu
        
        if (eof < 0) exit
        if (nspu > 0) then
          allocate (elem_cnt(nspu))
          backspace (107)
          read (107,*,iostat=eof) k, rcu_out(i)%name, rcu_out(i)%area_ha, nspu, (elem_cnt(isp), isp = 1, nspu)

          !!save the object number of each defining unit
          if (nspu == 1) then
            allocate (rcu_out(i)%num(1))
            rcu_out(i)%num_tot = 1
            rcu_out(i)%num(1) = elem_cnt(1)
          else
          !! nspu > 1
          ielem = 0
          do ii = 2, nspu
            ie1 = elem_cnt(ii-1)
            if (elem_cnt(ii) > 0) then
              if (ii == nspu) then
                ielem = ielem + 1
              else
                if (elem_cnt(ii+1) > 0) then
                  ielem = ielem + 1
                end if
              end if
            else
              ielem = ielem + abs(elem_cnt(ii)) - elem_cnt(ii-1) + 1
            end if
          end do
          allocate (rcu_out(i)%num(ielem))
          rcu_out(i)%num_tot = ielem

          ielem = 0
          ii = 1
          do while (ii <= nspu)
            ie1 = elem_cnt(ii)
            if (ii == nspu) then
              ielem = ielem + 1
              ii = ii + 1
              rcu_out(i)%num(ielem) = ie1
            else
              ie2 = elem_cnt(ii+1)
              if (ie2 > 0) then
                ielem = ielem + 1
                rcu_out(i)%num(ielem) = ie1
                ielem = ielem + 1
                rcu_out(i)%num(ielem) = ie2
              else
                ie2 = abs(ie2)
                do ie = ie1, ie2
                  ielem = ielem + 1
                  rcu_out(i)%num(ielem) = ie
                end do
              end if
              ii = ii + 2
            end if
          end do
          deallocate (elem_cnt)
          end if   !nspu > 1
        else
          !!all hrus are in region 
          allocate (rcu_out(i)%num(sp_ob%hru))
          rcu_out(i)%num_tot = sp_ob%res
          do ires = 1, sp_ob%res
            rcu_out(i)%num(ires) = ires
          end do      
        end if

      end do    ! i = 1, mreg
      exit
         
      db_mx%res_out = mreg
      end do 
      end if	  
        
    !! setting up regions for reservoir soft cal and/or output by type
    inquire (file=in_regs%def_res_reg, exist=i_exist)
    if (i_exist /= 0 .or. in_regs%def_res_reg /= 'null') then
      do
        open (107,file=in_regs%def_res_reg)
        read (107,*,iostat=eof) titldum
        if (eof < 0) exit
        read (107,*,iostat=eof) mreg
        if (eof < 0) exit
        read (107,*,iostat=eof) header

      do i = 1, mreg

        read (107,*,iostat=eof) k, rcu_cal(i)%name, rcu_cal(i)%area_ha, nspu
        
        if (eof < 0) exit
        if (nspu > 0) then
          allocate (elem_cnt(nspu))
          backspace (107)
          read (107,*,iostat=eof) k, rcu_cal(i)%name, rcu_cal(i)%area_ha, nspu, (elem_cnt(isp), isp = 1, nspu)

          !!save the object number of each defining unit
          if (nspu == 1) then
            allocate (rcu_cal(i)%num(1))
            rcu_cal(i)%num_tot = 1
            rcu_cal(i)%num(1) = elem_cnt(1)
          else
          !! nspu > 1
          ielem = 0
          do ii = 2, nspu
            ie1 = elem_cnt(ii-1)
            if (elem_cnt(ii) > 0) then
              if (ii == nspu) then
                ielem = ielem + 1
              else
                if (elem_cnt(ii+1) > 0) then
                  ielem = ielem + 1
                end if
              end if
            else
              ielem = ielem + abs(elem_cnt(ii)) - elem_cnt(ii-1) + 1
            end if
          end do
          allocate (rcu_cal(i)%num(ielem))
          rcu_cal(i)%num_tot = ielem

          ielem = 0
          ii = 1
          do while (ii <= nspu)
            ie1 = elem_cnt(ii)
            if (ii == nspu) then
              ielem = ielem + 1
              ii = ii + 1
              rcu_cal(i)%num(ielem) = ie1
            else
              ie2 = elem_cnt(ii+1)
              if (ie2 > 0) then
                ielem = ielem + 1
                rcu_cal(i)%num(ielem) = ie1
                ielem = ielem + 1
                rcu_cal(i)%num(ielem) = ie2
              else
                ie2 = abs(ie2)
                do ie = ie1, ie2
                  ielem = ielem + 1
                  rcu_cal(i)%num(ielem) = ie
                end do
              end if
              ii = ii + 2
            end if
          end do
          deallocate (elem_cnt)
          end if   !nspu > 1
        else
          !!all hrus are in region 
          allocate (rcu_reg(i)%num(sp_ob%hru))
          rcu_reg(i)%num_tot = sp_ob%res
          do ires = 1, sp_ob%res
            rcu_reg(i)%num(ihru) = ires
          end do      
        end if

      end do    ! i = 1, mreg
      exit
         
      db_mx%res_reg = mreg
      end do 
      end if	  
      
      !! if no regions are input, don't need elements
      if (mreg > 0) then
        do ireg = 1, mreg
          rcu_cal(ireg)%lum_ha_tot = 0.
          rcu_cal(ireg)%lum_num_tot = 0
          rcu_cal(ireg)%lum_ha_tot = 0.
          !allocate (region(ireg)%lum_ha_tot(db_mx%landuse))
          !allocate (region(ireg)%lum_num_tot(db_mx%landuse))
          !allocate (rwb_a(ireg)%lum(db_mx%landuse))
          !allocate (rnb_a(ireg)%lum(db_mx%landuse))
          !allocate (rls_a(ireg)%lum(db_mx%landuse))
          !allocate (rpw_a(ireg)%lum(db_mx%landuse))
        end do
      end if
      
      !!read data for each element in all landscape cataloging units
      inquire (file=in_regs%ele_res, exist=i_exist)
      if (i_exist /= 0) then
      do
        open (107,file=in_regs%ele_res)
        read (107,*,iostat=eof) titldum
        if (eof < 0) exit
        read (107,*,iostat=eof) header
        if (eof < 0) exit
        imax = 0
          do while (eof <= 0)
              read (107,*,iostat=eof) i
              if (eof < 0) exit
              imax = Max(i,imax)
          end do

        allocate (rcu_elem(imax))

        rewind (107)
        read (107,*) titldum
        read (107,*) header

        do isp = 1, imax
          read (107,*,iostat=eof) i
          backspace (107)
          read (107,*,iostat=eof) k, rcu_elem(i)%name, rcu_elem(i)%obtyp, rcu_elem(i)%obtypno,      &
                                    rcu_elem(i)%bsn_frac, rcu_elem(i)%sub_frac, rcu_elem(i)%reg_frac
          if (eof < 0) exit
        end do
        exit
      end do
      end if
      
      ! set hru number from element number and set hru areas in the region
      do ireg = 1, mreg
        do ires = 1, rcu_reg(ireg)%num_tot      !elements have to be hru or hru_lte
          ielem = rcu_reg(ireg)%num(ires)
          !switch %num from element number to hru number
          rcu_cal(ireg)%num(ihru) = rcu_elem(ielem)%obtypno
          rcu_cal(ireg)%hru_ha(ihru) = rcu_elem(ielem)%sub_frac * rcu_cal(ireg)%area_ha
        end do
      end do
      
      close (107)

      return
      end subroutine res_elements_read