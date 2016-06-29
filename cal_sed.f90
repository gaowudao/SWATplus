      subroutine cal_sed

      use parm
      use hydrograph_module
      use subbasin_module
      use hru_module
!      use wateruse_module
      use climate_module
      use aquifer_module
      use channel_module
      use sd_hru_module
      use sd_channel_module
      use basin_module
      use jrw_datalib_module
      use conditional_module
      use reservoir_module

      !calibrate sediment
        ical_sed = 0
        
        ! 1st time of concentration adjustment
        do ireg = 1, db_mx%lscal_reg
          do ilum = 1, lscal(ireg)%lum_num
            do ihru_s = 1, lscal(ireg)%num_tot
              iihru = lscal(ireg)%num(ihru_s)
              if (lscal(ireg)%lum(ilum)%lum_no == hru(ihru)%land_use_mgt) then
                !set parms for 1st sediment tconc calibration and rerun
                hru(iihru) = hru_init(iihru)
                soil(iihru) = soil_init(iihru)
                pcom(iihru) = pcom_init(iihru)
                lscal(ireg)%lum(ilum)%prm_prev = lscal(ireg)%lum(ilum)%prm
                lscal(ireg)%lum(ilum)%prev = lscal(ireg)%lum(ilum)%aa

                chg_val = lscal(ireg)%lum(ilum)%meas%sed / lscal(ireg)%lum(ilum)%aa%sed
                chg_val = chg_val ** 1.7857
                chg_val = amin1 (chg_val, ls_prms(4)%pos)
                chg_val = Max (chg_val, ls_prms(4)%neg)
                lscal(ireg)%lum(ilum)%prm%tconc = chg_val
                tconc(iihru) = tconc(iihru) / chg_val
                tconc(iihru) = amin1 (tconc(iihru), 1400.)
                tconc(iihru) = Max (tconc(iihru), 0.)
              end if
            end do
            lscal(ireg)%lum(ilum)%nbyr = 0
            lscal(ireg)%lum(ilum)%precip_aa = 0.
            lscal(ireg)%lum(ilum)%aa = lscal_z
          end do
        end do
        ! 1st cn adjustment 
        call time_control
        
        do iter = 1, 2
          ! additional adjust sediment using tconc
          do isl = 1, 3
          do ireg = 1, db_mx%lscal_reg
          do ilum = 1, lscal(ireg)%lum_num
            do ihru_s = 1, lscal(ireg)%num_tot
              iihru = lscal(ireg)%num(ihru_s)
              if (lscal(ireg)%lum(ilum)%lum_no == hru(ihru)%land_use_mgt) then
                !set parms for 1st sediment tconc calibration and rerun
                hru(iihru) = hru_init(iihru)
                soil(iihru) = soil_init(iihru)
                pcom(iihru) = pcom_init(iihru)
                lscal(ireg)%lum(ilum)%prm_prev = lscal(ireg)%lum(ilum)%prm
                lscal(ireg)%lum(ilum)%prev = lscal(ireg)%lum(ilum)%aa
                
                meas = lscal(ireg)%lum(ilum)%meas%sed
                chg_val = - (lscal(ireg)%lum(ilum)%prm_prev%tconc - lscal(ireg)%lum(ilum)%prm_prev%tconc)                  &
                            * (lscal(ireg)%lum(ilum)%aa%sed - meas) / (lscal(ireg)%lum(ilum)%prev%sed - meas)
                chg_val = amin1 (chg_val, ls_prms(4)%pos)
                chg_val = Max (chg_val, ls_prms(4)%neg)
                lscal(ireg)%lum(ilum)%prm%tconc = chg_val
                if (chg_val > .001) then
                tconc(iihru) = tconc(iihru) / chg_val
                tconc(iihru) = amin1 (tconc(iihru), 1400.)
                tconc(iihru) = Max (tconc(iihru), 0.)
                end if
              end if
            end do
            lscal(ireg)%lum(ilum)%nbyr = 0
            lscal(ireg)%lum(ilum)%precip_aa = 0.
            lscal(ireg)%lum(ilum)%aa = lscal_z
          end do
        end do
        ! cn adjustment 
        call time_control
        ! if within uncertainty limits (in each lum) - go on to next variable
        
        end do      ! icn
          
        ! 1st slope adjustment
        do ireg = 1, db_mx%lscal_reg
          do ilum = 1, lscal(ireg)%lum_num
              !check all hru's for proper lum
              do iihru = 1, mhru
                !set parms for 1st surface runoff calibration and rerun
                if (hru(iihru)%land_use_mgt == lscal(ireg)%lum(ilum)%lum_no) then
                  hru(iihru) = hru_init(iihru)
                  soil(iihru) = soil_init(iihru)
                  pcom(iihru) = pcom_init(iihru)
                  lscal(ireg)%lum(ilum)%prm_prev = lscal(ireg)%lum(ilum)%prm
                  lscal(ireg)%lum(ilum)%prev = lscal(ireg)%lum(ilum)%aa
                  !call time_control - check if reinitializing in working

                  chg_val = lscal(ireg)%lum(ilum)%meas%sed / lscal(ireg)%lum(ilum)%aa%sed
                  chg_val = amin1 (chg_val, ls_prms(5)%pos)
                  chg_val = Max (chg_val, ls_prms(5)%neg)
                  lscal(ireg)%lum(ilum)%prm%slope = chg_val
                  
                  hru(iihru)%topo%slope = hru(iihru)%topo%slope - chg_val
                  hru(iihru)%topo%slope = amin1 (hru(iihru)%topo%slope, 2.)
                  hru(iihru)%topo%slope = Max (hru(iihru)%topo%slope, .0000001)
                  xm = 0.6 * (1. - Exp(-35.835 * hru(iihru)%topo%slope))    
                  sin_sl = Sin(Atan(hru(iihru)%topo%slope))
                  usle_ls(iihru) = (hru(iihru)%topo%slope / 22.128) ** xm * (65.41 * sin_sl * sin_sl + 4.56 * sin_sl + .065)
                  usle_mult(iihru) = soil(iihru)%phys(1)%rock * soil(iihru)%usle_k * terr_p * usle_ls(iihru) * 11.8
                end if
              end do
            lscal(ireg)%lum(ilum)%nbyr = 0
            lscal(ireg)%lum(ilum)%precip_aa = 0.
            lscal(ireg)%lum(ilum)%aa = lscal_z
          end do
        end do
        ! 1st esco adjustment 
        call time_control
        
        ! adjust sediment using slope and slope length
        do isl = 1, 3
          do ireg = 1, db_mx%lscal_reg
          do ilum = 1, lscal(ireg)%lum_num
              !check all hru's for proper lum
              do iihru = 1, mhru
                !set parms for 1st surface runoff calibration and rerun
                if (hru(iihru)%land_use_mgt == lscal(ireg)%lum(ilum)%lum_no) then
                  hru(iihru) = hru_init(iihru)
                  soil(iihru) = soil_init(iihru)
                  pcom(iihru) = pcom_init(iihru)
                  lscal(ireg)%lum(ilum)%prm_prev = lscal(ireg)%lum(ilum)%prm
                  lscal(ireg)%lum(ilum)%prev = lscal(ireg)%lum(ilum)%aa
                
                  meas = lscal(ireg)%lum(ilum)%meas%sed
                  chg_val = - (lscal(ireg)%lum(ilum)%prm_prev%tconc - lscal(ireg)%lum(ilum)%prm_prev%tconc)                  &
                            * (lscal(ireg)%lum(ilum)%aa%sed - meas) / (lscal(ireg)%lum(ilum)%prev%sed - meas)
                  chg_val = amin1 (chg_val, ls_prms(5)%pos)
                  chg_val = Max (chg_val, ls_prms(5)%neg)
                  lscal(ireg)%lum(ilum)%prm%slope = chg_val
                  
                  hru(iihru)%topo%slope = hru(iihru)%topo%slope - chg_val
                  hru(iihru)%topo%slope = amin1 (hru(iihru)%topo%slope, 2.)
                  hru(iihru)%topo%slope = Max (hru(iihru)%topo%slope, .0000001)
                  xm = 0.6 * (1. - Exp(-35.835 * hru(iihru)%topo%slope))    
                  sin_sl = Sin(Atan(hru(iihru)%topo%slope))
                  usle_ls(iihru) = (hru(iihru)%topo%slope / 22.128) ** xm * (65.41 * sin_sl * sin_sl + 4.56 * sin_sl + .065)
                  usle_mult(iihru) = soil(iihru)%phys(1)%rock * soil(iihru)%usle_k * terr_p * usle_ls(iihru) * 11.8
                end if
              end do
            lscal(ireg)%lum(ilum)%nbyr = 0
            lscal(ireg)%lum(ilum)%precip_aa = 0.
            lscal(ireg)%lum(ilum)%aa = lscal_z
          end do
          end do
          ! slope adjustment 
          call time_control
          ! if within uncertainty limits (in each lum) - go on to next variable
        
        end do      ! isl
        end do      ! iter
      
	  return
      end subroutine cal_sed