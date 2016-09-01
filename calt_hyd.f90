      subroutine calt_hyd

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

      !calibrate hydrology
        ical_hyd = 0
        iter_all = 1
        iter_ind = 1
        
      do iterall = 1, iter_all
        ! 1st cn2 adjustment
        isim = 0
        do ireg = 1, db_mx%lscalt_reg
          do ilum = 1, lscalt(ireg)%lum_num
            soft = lscalt(ireg)%lum(ilum)%meas%srr * lscalt(ireg)%lum(ilum)%precip_aa
            diff = 0.
            if (soft > 1.e-6) diff = abs((soft - lscalt(ireg)%lum(ilum)%aa%srr) / soft)
            if (diff > .02 .and. lscalt(ireg)%lum(ilum)%ha > 1.e-6 .and. lscalt(ireg)%lum(ilum)%prm_lim%cn < 1.e-6) then
            isim = 1
            
                lscalt(ireg)%lum(ilum)%prm_prev = lscalt(ireg)%lum(ilum)%prm
                lscalt(ireg)%lum(ilum)%prev = lscalt(ireg)%lum(ilum)%aa

                diff = lscalt(ireg)%lum(ilum)%meas%srr * lscalt(ireg)%lum(ilum)%precip_aa - lscalt(ireg)%lum(ilum)%aa%srr
                chg_val = diff / 15.     !assume 10 mm runoff for 1 cn
                lscalt(ireg)%lum(ilum)%prm_prev%cn = lscalt(ireg)%lum(ilum)%prm%cn
                lscalt(ireg)%lum(ilum)%prm%cn = lscalt(ireg)%lum(ilum)%prm%cn + chg_val
                lscalt(ireg)%lum(ilum)%prev%srr = lscalt(ireg)%lum(ilum)%aa%srr
                
                if (lscalt(ireg)%lum(ilum)%prm%cn >= ls_prms(1)%pos) then
                  chg_val = ls_prms(1)%pos - lscalt(ireg)%lum(ilum)%prm_prev%cn
                  lscalt(ireg)%lum(ilum)%prm%cn = ls_prms(1)%pos
                  lscalt(ireg)%lum(ilum)%prm_lim%cn = 1.
                end if
                if (lscalt(ireg)%lum(ilum)%prm%cn <= ls_prms(1)%neg) then
                  chg_val = ls_prms(1)%neg - lscalt(ireg)%lum(ilum)%prm_prev%cn
                  lscalt(ireg)%lum(ilum)%prm%cn = ls_prms(1)%neg
                  lscalt(ireg)%lum(ilum)%prm_lim%cn = 1.
                end if

            do ihru_s = 1, lscalt(ireg)%num_tot
              iihru = lscalt(ireg)%num(ihru_s)
              !if (lscalt(ireg)%lum(ilum)%lum_no == hru(ihru)%land_use_mgt) then
                !set parms for 1st surface runoff calibration and rerun
                sd(iihru) = sd_init(iihru)
                sd(iihru)%cn2 = sd(iihru)%cn2 + chg_val
                sd(iihru)%cn2 = amin1 (sd(iihru)%cn2, ls_prms(1)%up)
                sd(iihru)%cn2 = Max (sd(iihru)%cn2, ls_prms(1)%lo)
                qn1 = sd(iihru)%cn2 - (20. * (100. - sd(iihru)%cn2)) /                     &
                     (100. - sd(iihru)%cn2 + EXP(2.533 - .063 * (100. - sd(iihru)%cn2)))
                qn1 = Max(qn1, .4 * sd(iihru)%cn2)
                qn3 = sd(iihru)%cn2 * EXP(.00673 * (100. - sd(iihru)%cn2))
                sd(iihru)%smx = 254. * (100. / qn1 - 1.) 
                s3 = 254. * (100. / qn3 - 1.)
                rto3 = 1. - s3 / sd(iihru)%smx
                rtos = 1. - 2.54 / sd(iihru)%smx
                sumul = sd(iihru)%por
                sumfc = sd(iihru)%awc + sd(iihru)%cn3_swf * (sumul - sd(iihru)%awc)
                !! calculate shape parameters
                call ascrv(rto3, rtos, sumfc, sumul, sd(iihru)%wrt1, sd(iihru)%wrt2)
                sd_init(iihru) = sd(iihru)
              !end if
            end do
            lscalt(ireg)%lum(ilum)%nbyr = 0
            lscalt(ireg)%lum(ilum)%precip_aa = 0.
            lscalt(ireg)%lum(ilum)%aa = lscal_z
          end if
          end do
        end do
        ! 1st cn2 adjustment 
        if (isim > 0) then
          write (4304,*) " first cn2 adj "
          call time_control
        end if

          ! adjust surface runoff using cn2
          do icn = 1, iter_ind
          isim = 0
          do ireg = 1, db_mx%lscalt_reg
          do ilum = 1, lscalt(ireg)%lum_num
            soft = lscalt(ireg)%lum(ilum)%meas%srr * lscalt(ireg)%lum(ilum)%precip_aa
            diff = 0.
            if (soft > 1.e-6) diff = abs((soft - lscalt(ireg)%lum(ilum)%aa%srr) / soft)
            if (diff > .02 .and. lscalt(ireg)%lum(ilum)%ha > 1.e-6 .and. lscalt(ireg)%lum(ilum)%prm_lim%cn < 1.e-6) then
            isim = 1
            
                rmeas = lscalt(ireg)%lum(ilum)%meas%srr * lscalt(ireg)%lum(ilum)%precip_aa
                denom = lscalt(ireg)%lum(ilum)%prev%srr - lscalt(ireg)%lum(ilum)%aa%srr
                if (denom > 1.e-6) then
                  chg_val = - (lscalt(ireg)%lum(ilum)%prm_prev%cn - lscalt(ireg)%lum(ilum)%prm%cn)                  &
                    * (lscalt(ireg)%lum(ilum)%aa%srr - rmeas) / denom
                else
                  chg_val = diff / 200.
                end if
                lscalt(ireg)%lum(ilum)%prm_prev%cn = lscalt(ireg)%lum(ilum)%prm%cn
                lscalt(ireg)%lum(ilum)%prm%cn = lscalt(ireg)%lum(ilum)%prm%cn + chg_val
                lscalt(ireg)%lum(ilum)%prev%srr = lscalt(ireg)%lum(ilum)%aa%srr
                                
                if (lscalt(ireg)%lum(ilum)%prm%cn >= ls_prms(1)%pos) then
                  chg_val = ls_prms(1)%pos - lscalt(ireg)%lum(ilum)%prm_prev%cn
                  lscalt(ireg)%lum(ilum)%prm%cn = ls_prms(1)%pos
                  lscalt(ireg)%lum(ilum)%prm_lim%cn = 1.
                end if
                if (lscalt(ireg)%lum(ilum)%prm%cn <= ls_prms(1)%neg) then
                  chg_val = lscalt(ireg)%lum(ilum)%prm_prev%cn - ls_prms(1)%neg
                  lscalt(ireg)%lum(ilum)%prm%cn = ls_prms(1)%neg
                  lscalt(ireg)%lum(ilum)%prm_lim%cn = 1.
                end if
            
            !check all hru's for proper lum
            do ihru_s = 1, lscalt(ireg)%num_tot
              iihru = lscalt(ireg)%num(ihru_s)
              !if (lscalt(ireg)%lum(ilum)%lum_no == hru(ihru)%land_use_mgt) then
                !set parms for surface runoff calibration and rerun
                sd(iihru) = sd_init(iihru)
                sd(iihru)%cn2 = sd(iihru)%cn2 + chg_val
                sd(iihru)%cn2 = amin1 (sd(iihru)%cn2, ls_prms(1)%up)
                sd(iihru)%cn2 = Max (sd(iihru)%cn2, ls_prms(1)%lo)
                qn1 = sd(iihru)%cn2 - (20. * (100. - sd(iihru)%cn2)) /                     &
                     (100. - sd(iihru)%cn2 + EXP(2.533 - .063 * (100. - sd(iihru)%cn2)))
                qn1 = Max(qn1, .4 * sd(iihru)%cn2)
                qn3 = sd(iihru)%cn2 * EXP(.00673 * (100. - sd(iihru)%cn2))
                sd(iihru)%smx = 254. * (100. / qn1 - 1.) 
                s3 = 254. * (100. / qn3 - 1.)
                rto3 = 1. - s3 / sd(iihru)%smx
                rtos = 1. - 2.54 / sd(iihru)%smx
                sumul = sd(iihru)%por
                sumfc = sd(iihru)%awc + sd(iihru)%cn3_swf * (sumul - sd(iihru)%awc)
                !! calculate shape parameters
                call ascrv(rto3, rtos, sumfc, sumul, sd(iihru)%wrt1, sd(iihru)%wrt2)
                sd_init(iihru) = sd(iihru)
              !end if
            end do
            lscalt(ireg)%lum(ilum)%nbyr = 0
            lscalt(ireg)%lum(ilum)%precip_aa = 0.
            lscalt(ireg)%lum(ilum)%aa = lscal_z
            !else
            !lscalt(ireg)%lum(ilum)%prm_lim%etco = 1.
            end if
          end do
        end do
        ! cn2 adjustment
        if (isim > 0) then
          write (4304,*) " cn2 adj "
          call time_control
        end if
        end do      ! icn
          
        ! 1st etco adjustment
        isim = 0
        do ireg = 1, db_mx%lscalt_reg
          do ilum = 1, lscalt(ireg)%lum_num
            !check all hru's for proper lum
            soft = lscalt(ireg)%lum(ilum)%meas%etr * lscalt(ireg)%lum(ilum)%precip_aa
            diff = 0.
            if (soft > 1.e-6) diff = abs((soft - lscalt(ireg)%lum(ilum)%aa%etr) / soft)
            if (diff > .02 .and. lscalt(ireg)%lum(ilum)%ha > 1.e-6 .and. lscalt(ireg)%lum(ilum)%prm_lim%etco < 1.e-6) then
            isim = 1
            
                lscalt(ireg)%lum(ilum)%prm_prev = lscalt(ireg)%lum(ilum)%prm
                lscalt(ireg)%lum(ilum)%prev = lscalt(ireg)%lum(ilum)%aa

                diff = lscalt(ireg)%lum(ilum)%meas%etr * lscalt(ireg)%lum(ilum)%precip_aa - lscalt(ireg)%lum(ilum)%aa%etr
                chg_val = diff / 200.     ! increment etco .05 for every 10 mm difference
                lscalt(ireg)%lum(ilum)%prm_prev%etco = lscalt(ireg)%lum(ilum)%prm%etco
                lscalt(ireg)%lum(ilum)%prm%etco = lscalt(ireg)%lum(ilum)%prm%etco + chg_val
                lscalt(ireg)%lum(ilum)%prev%etr = lscalt(ireg)%lum(ilum)%aa%etr
                
                if (lscalt(ireg)%lum(ilum)%prm%etco >= ls_prms(7)%pos) then
                  chg_val = ls_prms(7)%pos - lscalt(ireg)%lum(ilum)%prm_prev%etco
                  lscalt(ireg)%lum(ilum)%prm%etco = ls_prms(7)%pos
                  lscalt(ireg)%lum(ilum)%prm_lim%etco = 1.
                end if
                if (lscalt(ireg)%lum(ilum)%prm%etco <= ls_prms(7)%neg) then
                  chg_val = lscalt(ireg)%lum(ilum)%prm_prev%etco - ls_prms(7)%neg
                  lscalt(ireg)%lum(ilum)%prm%etco = ls_prms(7)%neg
                  lscalt(ireg)%lum(ilum)%prm_lim%etco = 1.
                end if
                           
            do ihru_s = 1, lscalt(ireg)%num_tot
                iihru = lscalt(ireg)%num(ihru_s)
                !if (lscalt(ireg)%lum(ilum)%lum_no == hru(ihru)%land_use_mgt) then
                !set parms for 1st et calibration and rerun
                sd(iihru) = sd_init(iihru)
                sd(iihru)%etco = sd(iihru)%etco + chg_val
                sd(iihru)%etco = amin1 (sd(iihru)%etco, ls_prms(7)%up)
                sd(iihru)%etco = Max (sd(iihru)%etco, ls_prms(7)%lo)
                sd_init(iihru) = sd(iihru)
              !end if
            end do
            lscalt(ireg)%lum(ilum)%nbyr = 0
            lscalt(ireg)%lum(ilum)%precip_aa = 0.
            lscalt(ireg)%lum(ilum)%aa = lscal_z
          !else
            !lscalt(ireg)%lum(ilum)%prm_lim%etco = 1.
          end if
          end do
        end do
        ! 1st etco adjustment 
        if (isim > 0) then
          write (4304,*) " first etco adj "
          call time_control
        end if
        
        ! adjust et using etco
        do ietco = 1, iter_ind
          isim = 0
          do ireg = 1, db_mx%lscalt_reg
          do ilum = 1, lscalt(ireg)%lum_num
            !check all hru's for proper lum
            soft = lscalt(ireg)%lum(ilum)%meas%etr * lscalt(ireg)%lum(ilum)%precip_aa
            diff = 0.
            if (soft > 1.e-6) diff = abs((soft - lscalt(ireg)%lum(ilum)%aa%etr) / soft)
            if (diff > .02 .and. lscalt(ireg)%lum(ilum)%ha > 1.e-6 .and. lscalt(ireg)%lum(ilum)%prm_lim%etco < 1.e-6) then
            isim = 1

                rmeas = lscalt(ireg)%lum(ilum)%meas%etr * lscalt(ireg)%lum(ilum)%precip_aa
                denom = lscalt(ireg)%lum(ilum)%prev%etr - lscalt(ireg)%lum(ilum)%aa%etr
                if (denom > 1.e-6) then
                  chg_val = - (lscalt(ireg)%lum(ilum)%prm_prev%etco - lscalt(ireg)%lum(ilum)%prm%etco)                  &
                    * (lscalt(ireg)%lum(ilum)%aa%etr - rmeas) / denom
                else
                  chg_val = diff / 200.
                end if
                lscalt(ireg)%lum(ilum)%prm_prev%etco = lscalt(ireg)%lum(ilum)%prm%etco
                lscalt(ireg)%lum(ilum)%prm%etco = lscalt(ireg)%lum(ilum)%prm%etco + chg_val
                lscalt(ireg)%lum(ilum)%prev%etr = lscalt(ireg)%lum(ilum)%aa%etr
                      
                if (lscalt(ireg)%lum(ilum)%prm%etco >= ls_prms(7)%pos) then
                  chg_val = ls_prms(7)%pos - lscalt(ireg)%lum(ilum)%prm_prev%etco
                  lscalt(ireg)%lum(ilum)%prm%etco = ls_prms(7)%pos
                  lscalt(ireg)%lum(ilum)%prm_lim%etco = 1.
                end if
                if (lscalt(ireg)%lum(ilum)%prm%etco <= ls_prms(7)%neg) then
                  chg_val = lscalt(ireg)%lum(ilum)%prm_prev%etco - ls_prms(7)%neg
                  lscalt(ireg)%lum(ilum)%prm%etco = ls_prms(7)%neg
                  lscalt(ireg)%lum(ilum)%prm_lim%etco = 1.
                end if
                
            do ihru_s = 1, lscalt(ireg)%num_tot
                iihru = lscalt(ireg)%num(ihru_s)
                !if (lscalt(ireg)%lum(ilum)%lum_no == hru(ihru)%land_use_mgt) then
                !set parms for et calibration and rerun
                sd(iihru) = sd_init(iihru)
                sd(iihru)%etco = sd(iihru)%etco + chg_val
                sd(iihru)%etco = amin1 (sd(iihru)%etco, ls_prms(7)%up)
                sd(iihru)%etco = Max (sd(iihru)%etco, ls_prms(7)%lo)
                sd_init(iihru) = sd(iihru)
              !end if
            end do
            lscalt(ireg)%lum(ilum)%nbyr = 0
            lscalt(ireg)%lum(ilum)%precip_aa = 0.
            lscalt(ireg)%lum(ilum)%aa = lscal_z
          end if
          end do
          end do
          ! et adjustment 
          if (isim > 0) then
            write (4304,*) " etco adj "
            call time_control
          end if
        
        end do      ! ietco

        ! 1st perco adjustment (bottom layer) for percolation
        isim = 0
        do ireg = 1, db_mx%lscalt_reg
          do ilum = 1, lscalt(ireg)%lum_num
            !check all hru's for proper lum
            soft = lscalt(ireg)%lum(ilum)%meas%pcr * lscalt(ireg)%lum(ilum)%precip_aa
            diff = 0.
            if (soft > 1.e-6) diff = abs((soft - lscalt(ireg)%lum(ilum)%aa%pcr) / soft)
            if (diff > .1 .and. lscalt(ireg)%lum(ilum)%ha > 1.e-6 .and. lscalt(ireg)%lum(ilum)%prm_lim%perco < 1.e-6) then
            isim = 1
            
                lscalt(ireg)%lum(ilum)%prm_prev = lscalt(ireg)%lum(ilum)%prm
                lscalt(ireg)%lum(ilum)%prev = lscalt(ireg)%lum(ilum)%aa

                chg_val = (soft - lscalt(ireg)%lum(ilum)%aa%pcr) / 200.      ! .5 increase for every 100 mm difference
                lscalt(ireg)%lum(ilum)%prm_prev%perco = lscalt(ireg)%lum(ilum)%prm%perco 
                lscalt(ireg)%lum(ilum)%prm%perco = lscalt(ireg)%lum(ilum)%prm%perco + chg_val
                lscalt(ireg)%lum(ilum)%prev%pcr = lscalt(ireg)%lum(ilum)%aa%pcr
                           
                if (lscalt(ireg)%lum(ilum)%prm%perco >= ls_prms(8)%pos) then
                  lscalt(ireg)%lum(ilum)%prm%perco = ls_prms(8)%pos
                  chg_val = ls_prms(8)%pos
                  lscalt(ireg)%lum(ilum)%prm_lim%perco = 1.
                end if
                if (lscalt(ireg)%lum(ilum)%prm%perco <= ls_prms(8)%neg) then
                  lscalt(ireg)%lum(ilum)%prm%perco = ls_prms(8)%neg
                  chg_val = ls_prms(8)%neg
                  lscalt(ireg)%lum(ilum)%prm_lim%perco = 1.
                end if

            do ihru_s = 1, lscalt(ireg)%num_tot
              iihru = lscalt(ireg)%num(ihru_s)
              !if (lscalt(ireg)%lum(ilum)%lum_no == hru(ihru)%land_use_mgt) then
                !set parms for 1st surface runoff calibration and rerun
                sd(iihru) = sd_init(iihru)
                sd(iihru)%perco = sd(iihru)%perco - chg_val
                sd(iihru)%perco = amin1 (sd(iihru)%perco, ls_prms(8)%up)
                sd(iihru)%perco = Max (sd(iihru)%perco, ls_prms(8)%lo)
                sd_init(iihru) = sd(iihru)
                !idb = sd(iihru)%props
                !sd(iihru)%hk = (sd(iihru)%por - sd(iihru)%awc) / (scon(sd_db(idb)%itext) * sd(iihru)%perco)
                !sd(iihru)%hk = Max(2., sd(iihru)%hk)
              !end if
            end do
            lscalt(ireg)%lum(ilum)%nbyr = 0
            lscalt(ireg)%lum(ilum)%precip_aa = 0.
            lscalt(ireg)%lum(ilum)%aa = lscal_z
            else
            lscalt(ireg)%lum(ilum)%prm_lim%perco = 1.
            end if
            end do
        end do
        ! 1st perco adjustment 
        if (isim > 0) then
          write (4304,*) " first perco adj "
          call time_control
        end if

          ! adjust percolation using perco
          do iperco = 1, iter_ind
          isim = 0
          do ireg = 1, db_mx%lscalt_reg
          do ilum = 1, lscalt(ireg)%lum_num
            soft = lscalt(ireg)%lum(ilum)%meas%pcr * lscalt(ireg)%lum(ilum)%precip_aa
            diff = 0.
            if (soft > 1.e-6) diff = abs((soft - lscalt(ireg)%lum(ilum)%aa%pcr) / soft)
            if (diff > .1 .and. lscalt(ireg)%lum(ilum)%ha > 1.e-6 .and. lscalt(ireg)%lum(ilum)%prm_lim%perco < 1.e-6) then
            isim = 1
            
                rmeas = lscalt(ireg)%lum(ilum)%meas%pcr * lscalt(ireg)%lum(ilum)%precip_aa
                denom = lscalt(ireg)%lum(ilum)%prev%pcr - lscalt(ireg)%lum(ilum)%aa%pcr
                if (denom > 1.e-6) then
                  chg_val = - (lscalt(ireg)%lum(ilum)%prm_prev%perco - lscalt(ireg)%lum(ilum)%prm%perco) *         &
                        (lscalt(ireg)%lum(ilum)%aa%pcr - rmeas) / denom
                else
                  chg_val = (soft - lscalt(ireg)%lum(ilum)%aa%pcr) / 200. 
                end if
                lscalt(ireg)%lum(ilum)%prm%perco = lscalt(ireg)%lum(ilum)%prm%perco + chg_val
                lscalt(ireg)%lum(ilum)%prm_prev%perco = lscalt(ireg)%lum(ilum)%prm%perco
                lscalt(ireg)%lum(ilum)%prev%pcr = lscalt(ireg)%lum(ilum)%aa%pcr
                                
                if (lscalt(ireg)%lum(ilum)%prm%perco >= ls_prms(8)%pos) then
                  chg_val = lscalt(ireg)%lum(ilum)%prm_prev%perco - ls_prms(8)%pos
                  lscalt(ireg)%lum(ilum)%prm%perco = ls_prms(8)%pos
                  lscalt(ireg)%lum(ilum)%prm_lim%perco = 1.
                end if
                if (lscalt(ireg)%lum(ilum)%prm%perco <= ls_prms(8)%neg) then
                  chg_val = lscalt(ireg)%lum(ilum)%prm_prev%perco - ls_prms(8)%neg
                  lscalt(ireg)%lum(ilum)%prm%perco = ls_prms(8)%neg
                  lscalt(ireg)%lum(ilum)%prm_lim%perco = 1.
                end if

            !check all hru's for proper lum
            do ihru_s = 1, lscalt(ireg)%num_tot
              iihru = lscalt(ireg)%num(ihru_s)
              !if (lscalt(ireg)%lum(ilum)%lum_no == hru(ihru)%land_use_mgt) then
                !set parms for surface runoff calibration and rerun
                sd(iihru) = sd_init(iihru)
                sd(iihru)%perco = sd(iihru)%perco - chg_val
                sd(iihru)%perco = amin1 (sd(iihru)%perco, ls_prms(8)%up)
                sd(iihru)%perco = Max (sd(iihru)%perco, ls_prms(8)%lo)
                sd_init(iihru) = sd(iihru)
                !idb = sd(iihru)%props
                !sd(iihru)%hk = (sd(iihru)%por - sd(iihru)%awc) / (scon(sd_db(idb)%itext) * sd(iihru)%perco)
                !sd(iihru)%hk = Max(2., sd(iihru)%hk)
              !end if
            end do
            lscalt(ireg)%lum(ilum)%nbyr = 0
            lscalt(ireg)%lum(ilum)%precip_aa = 0.
            lscalt(ireg)%lum(ilum)%aa = lscal_z
            else
            lscalt(ireg)%lum(ilum)%prm_lim%perco = 1.
            end if
          end do
          end do
        ! perco adjustment 
        if (isim > 0) then
          write (4304,*) " perco adj "
          call time_control
        end if
        
        end do      ! iperco  

        ! 1st revapc adjustment for groundwater flow
        isim = 0
        do ireg = 1, db_mx%lscalt_reg
          do ilum = 1, lscalt(ireg)%lum_num
            !check all hru's for proper lum
            soft = lscalt(ireg)%lum(ilum)%meas%lfr * lscalt(ireg)%lum(ilum)%precip_aa
            diff = 0.
            if (soft > 1.e-6) diff = abs((soft - lscalt(ireg)%lum(ilum)%aa%lfr) / soft)
            if (diff > .1 .and. lscalt(ireg)%lum(ilum)%ha > 1.e-6 .and. lscalt(ireg)%lum(ilum)%prm_lim%revapc < 1.e-6) then
            isim = 1
            
                lscalt(ireg)%lum(ilum)%prm_prev = lscalt(ireg)%lum(ilum)%prm
                lscalt(ireg)%lum(ilum)%prev = lscalt(ireg)%lum(ilum)%aa

                diff = lscalt(ireg)%lum(ilum)%meas%lfr * lscalt(ireg)%lum(ilum)%precip_aa - lscalt(ireg)%lum(ilum)%aa%lfr
                chg_val =  diff / 250.      ! increment revapc by 0.4 for 100 mm difference
                lscalt(ireg)%lum(ilum)%prm_prev%revapc = lscalt(ireg)%lum(ilum)%prm%revapc
                lscalt(ireg)%lum(ilum)%prm%revapc = lscalt(ireg)%lum(ilum)%prm%revapc - chg_val
                lscalt(ireg)%lum(ilum)%prev%lfr = lscalt(ireg)%lum(ilum)%aa%lfr
                           
                if (lscalt(ireg)%lum(ilum)%prm%revapc >= ls_prms(9)%pos) then
                  lscalt(ireg)%lum(ilum)%prm%revapc = ls_prms(9)%pos
                  chg_val = ls_prms(9)%pos
                  lscalt(ireg)%lum(ilum)%prm_lim%revapc = 1.
                end if
                if (lscalt(ireg)%lum(ilum)%prm%revapc <= ls_prms(9)%neg) then
                  lscalt(ireg)%lum(ilum)%prm%revapc = ls_prms(9)%neg
                  chg_val = ls_prms(9)%neg
                  lscalt(ireg)%lum(ilum)%prm_lim%revapc = 1.
                end if
                
            do ihru_s = 1, lscalt(ireg)%num_tot
              iihru = lscalt(ireg)%num(ihru_s)
              !if (lscalt(ireg)%lum(ilum)%lum_no == hru(ihru)%land_use_mgt) then
                !set parms for 1st surface runoff calibration and rerun
                sd(iihru) = sd_init(iihru)
                sd(iihru)%revapc = sd(iihru)%revapc + chg_val
                sd(iihru)%revapc = amin1 (sd(iihru)%revapc, ls_prms(9)%up)
                sd(iihru)%revapc = Max (sd(iihru)%revapc, ls_prms(9)%lo)
                sd_init(iihru)%revapc = sd(iihru)%revapc
                sd_init(iihru) = sd(iihru)
              !end if
            end do
            lscalt(ireg)%lum(ilum)%nbyr = 0
            lscalt(ireg)%lum(ilum)%precip_aa = 0.
            lscalt(ireg)%lum(ilum)%aa = lscal_z
          end if
          end do
        end do
        ! 1st revapc adjustment 
        if (isim > 0) then
          write (4304,*) " first revapc adj "
          call time_control
        end if

        ! adjust groundwater flow using revapc
        do ik = 1, iter_ind
          isim = 0
        do ireg = 1, db_mx%lscalt_reg
          do ilum = 1, lscalt(ireg)%lum_num
            soft = lscalt(ireg)%lum(ilum)%meas%lfr * lscalt(ireg)%lum(ilum)%precip_aa
            diff = 0.
            if (soft > 1.e-6) diff = abs((soft - lscalt(ireg)%lum(ilum)%aa%lfr) / soft)
            if (diff > .1 .and. lscalt(ireg)%lum(ilum)%ha > 1.e-6 .and. lscalt(ireg)%lum(ilum)%prm_lim%revapc < 1.e-6) then
            isim = 1
            
                rmeas = lscalt(ireg)%lum(ilum)%meas%lfr * lscalt(ireg)%lum(ilum)%precip_aa
                denom = lscalt(ireg)%lum(ilum)%prev%lfr - lscalt(ireg)%lum(ilum)%aa%lfr
                if (denom > 1.e-6) then
                  chg_val = - (lscalt(ireg)%lum(ilum)%prm_prev%revapc - lscalt(ireg)%lum(ilum)%prm%revapc)                  &
                    * (lscalt(ireg)%lum(ilum)%aa%lfr - rmeas) / denom
                else
                  chg_val = diff / 250.
                end if
                lscalt(ireg)%lum(ilum)%prm_prev%revapc = lscalt(ireg)%lum(ilum)%prm%revapc
                lscalt(ireg)%lum(ilum)%prm%revapc = lscalt(ireg)%lum(ilum)%prm%revapc + chg_val
                lscalt(ireg)%lum(ilum)%prev%lfr = lscalt(ireg)%lum(ilum)%aa%lfr
                           
                if (lscalt(ireg)%lum(ilum)%prm%revapc >= ls_prms(9)%pos) then
                  lscalt(ireg)%lum(ilum)%prm%revapc = ls_prms(9)%pos
                  chg_val = ls_prms(9)%pos
                  lscalt(ireg)%lum(ilum)%prm_lim%revapc = 1.
                end if
                if (lscalt(ireg)%lum(ilum)%prm%revapc <= ls_prms(9)%neg) then
                  lscalt(ireg)%lum(ilum)%prm%revapc = ls_prms(9)%neg
                  chg_val = ls_prms(9)%neg
                  lscalt(ireg)%lum(ilum)%prm_lim%revapc = 1.
                end if
                
            !check all hru's for proper lum
            do ihru_s = 1, lscalt(ireg)%num_tot
              iihru = lscalt(ireg)%num(ihru_s)
              !if (lscalt(ireg)%lum(ilum)%lum_no == hru(ihru)%land_use_mgt) then
                !set parms for surface runoff calibration and rerun
                sd(iihru) = sd_init(iihru)
                sd(iihru)%revapc = sd(iihru)%revapc + chg_val
                sd(iihru)%revapc = amin1 (sd(iihru)%revapc, ls_prms(9)%up)
                sd(iihru)%revapc = Max (sd(iihru)%revapc, ls_prms(9)%lo)
                sd_init(iihru)%revapc = sd(iihru)%revapc
                sd_init(iihru) = sd(iihru)
              !end if
            end do
            lscalt(ireg)%lum(ilum)%nbyr = 0
            lscalt(ireg)%lum(ilum)%precip_aa = 0.
            lscalt(ireg)%lum(ilum)%aa = lscal_z
          end if
          end do
        end do
        ! revapc adjustment for lateral flow
        if (isim > 0) then
          write (4304,*) " revapc adj "
          call time_control
        end if
        end do  
          
        ! 1st cn3_swf adjustment
        isim = 0
        do ireg = 1, db_mx%lscalt_reg
          do ilum = 1, lscalt(ireg)%lum_num
            soft = lscalt(ireg)%lum(ilum)%meas%srr * lscalt(ireg)%lum(ilum)%precip_aa
            diff = 0.
            if (soft > 1.e-6) diff = abs((soft - lscalt(ireg)%lum(ilum)%aa%srr) / soft)
            if (diff > .02 .and. lscalt(ireg)%lum(ilum)%ha > 1.e-6 .and. lscalt(ireg)%lum(ilum)%prm_lim%cn3_swf < 1.e-6) then
            isim = 1
            
                lscalt(ireg)%lum(ilum)%prm_prev = lscalt(ireg)%lum(ilum)%prm
                lscalt(ireg)%lum(ilum)%prev = lscalt(ireg)%lum(ilum)%aa

                diff = lscalt(ireg)%lum(ilum)%meas%srr * lscalt(ireg)%lum(ilum)%precip_aa - lscalt(ireg)%lum(ilum)%aa%srr
                chg_val = diff / 300.     !assume 10 mm runoff for .3 cn3_swf
                lscalt(ireg)%lum(ilum)%prm_prev%cn3_swf = lscalt(ireg)%lum(ilum)%prm%cn3_swf
                lscalt(ireg)%lum(ilum)%prm%cn3_swf = lscalt(ireg)%lum(ilum)%prm%cn3_swf + chg_val
                lscalt(ireg)%lum(ilum)%prev%srr = lscalt(ireg)%lum(ilum)%aa%srr
                
                if (lscalt(ireg)%lum(ilum)%prm%cn3_swf >= ls_prms(10)%pos) then
                  chg_val = ls_prms(10)%pos - lscalt(ireg)%lum(ilum)%prm_prev%cn3_swf
                  lscalt(ireg)%lum(ilum)%prm%cn3_swf = ls_prms(10)%pos
                  lscalt(ireg)%lum(ilum)%prm_lim%cn3_swf = 1.
                end if
                if (lscalt(ireg)%lum(ilum)%prm%cn3_swf <= ls_prms(10)%neg) then
                  chg_val = ls_prms(10)%neg - lscalt(ireg)%lum(ilum)%prm_prev%cn3_swf
                  lscalt(ireg)%lum(ilum)%prm%cn3_swf = ls_prms(10)%neg
                  lscalt(ireg)%lum(ilum)%prm_lim%cn3_swf = 1.
                end if

            do ihru_s = 1, lscalt(ireg)%num_tot
              iihru = lscalt(ireg)%num(ihru_s)
              !if (lscalt(ireg)%lum(ilum)%lum_no == hru(ihru)%land_use_mgt) then
                !set parms for 1st surface runoff calibration and rerun
                sd(iihru) = sd_init(iihru)
                sd(iihru)%cn3_swf = sd(iihru)%cn3_swf - chg_val
                sd(iihru)%cn3_swf = amin1 (sd(iihru)%cn3_swf, ls_prms(10)%up)
                sd(iihru)%cn3_swf = Max (sd(iihru)%cn3_swf, ls_prms(10)%lo)
                qn1 = sd(iihru)%cn2 - (20. * (100. - sd(iihru)%cn2)) /                     &
                     (100. - sd(iihru)%cn2 + EXP(2.533 - .063 * (100. - sd(iihru)%cn2)))
                qn1 = Max(qn1, .4 * sd(iihru)%cn2)
                qn3 = sd(iihru)%cn2 * EXP(.00673 * (100. - sd(iihru)%cn2))
                sd(iihru)%smx = 254. * (100. / qn1 - 1.) 
                s3 = 254. * (100. / qn3 - 1.)
                rto3 = 1. - s3 / sd(iihru)%smx
                rtos = 1. - 2.54 / sd(iihru)%smx
                sumul = sd(iihru)%por
                sumfc = sd(iihru)%awc + sd(iihru)%cn3_swf * (sumul - sd(iihru)%awc)
                sumfc = Max (sumfc, .5 * sd(iihru)%awc)
                !! calculate shape parameters
                call ascrv(rto3, rtos, sumfc, sumul, sd(iihru)%wrt1, sd(iihru)%wrt2)
                sd_init(iihru) = sd(iihru)
              !end if
            end do
            lscalt(ireg)%lum(ilum)%nbyr = 0
            lscalt(ireg)%lum(ilum)%precip_aa = 0.
            lscalt(ireg)%lum(ilum)%aa = lscal_z
          end if
          end do
        end do
        ! 1st cn3_swf adjustment 
        if (isim > 0) then
          write (4304,*) " first cn3_swf adj "
          call time_control
        end if

          ! adjust surface runoff using cn3_swf
          do icn = 1, iter_ind
          isim = 0
          do ireg = 1, db_mx%lscalt_reg
          do ilum = 1, lscalt(ireg)%lum_num
            soft = lscalt(ireg)%lum(ilum)%meas%srr * lscalt(ireg)%lum(ilum)%precip_aa
            diff = 0.
            if (soft > 1.e-6) diff = abs((soft - lscalt(ireg)%lum(ilum)%aa%srr) / soft)
            if (diff > .02 .and. lscalt(ireg)%lum(ilum)%ha > 1.e-6 .and. lscalt(ireg)%lum(ilum)%prm_lim%cn3_swf < 1.e-6) then
            isim = 1
            
                rmeas = lscalt(ireg)%lum(ilum)%meas%srr * lscalt(ireg)%lum(ilum)%precip_aa
                denom = lscalt(ireg)%lum(ilum)%prev%srr - lscalt(ireg)%lum(ilum)%aa%srr
                if (denom > 1.e-6) then
                  chg_val = - (lscalt(ireg)%lum(ilum)%prm_prev%cn3_swf - lscalt(ireg)%lum(ilum)%prm%cn3_swf)                  &
                    * (lscalt(ireg)%lum(ilum)%aa%srr - rmeas) / denom
                else
                  chg_val = diff / 300.
                end if
                lscalt(ireg)%lum(ilum)%prm_prev%cn3_swf = lscalt(ireg)%lum(ilum)%prm%cn3_swf
                lscalt(ireg)%lum(ilum)%prm%cn3_swf = lscalt(ireg)%lum(ilum)%prm%cn3_swf + chg_val
                lscalt(ireg)%lum(ilum)%prev%srr = lscalt(ireg)%lum(ilum)%aa%srr
                                
                if (lscalt(ireg)%lum(ilum)%prm%cn3_swf >= ls_prms(1)%pos) then
                  chg_val = ls_prms(1)%pos - lscalt(ireg)%lum(ilum)%prm_prev%cn3_swf
                  lscalt(ireg)%lum(ilum)%prm%cn3_swf = ls_prms(1)%pos
                  lscalt(ireg)%lum(ilum)%prm_lim%cn3_swf = 1.
                end if
                if (lscalt(ireg)%lum(ilum)%prm%cn3_swf <= ls_prms(1)%neg) then
                  chg_val = lscalt(ireg)%lum(ilum)%prm_prev%cn3_swf - ls_prms(1)%neg
                  lscalt(ireg)%lum(ilum)%prm%cn3_swf = ls_prms(1)%neg
                  lscalt(ireg)%lum(ilum)%prm_lim%cn3_swf = 1.
                end if
            
            !check all hru's for proper lum
            do ihru_s = 1, lscalt(ireg)%num_tot
              iihru = lscalt(ireg)%num(ihru_s)
              !if (lscalt(ireg)%lum(ilum)%lum_no == hru(ihru)%land_use_mgt) then
                !set parms for surface runoff calibration and rerun
                sd(iihru) = sd_init(iihru)
                sd(iihru)%cn3_swf = sd(iihru)%cn3_swf - chg_val
                sd(iihru)%cn3_swf = amin1 (sd(iihru)%cn3_swf, ls_prms(10)%up)
                sd(iihru)%cn3_swf = Max (sd(iihru)%cn3_swf, ls_prms(10)%lo)
                qn1 = sd(iihru)%cn2 - (20. * (100. - sd(iihru)%cn2)) /                     &
                     (100. - sd(iihru)%cn2 + EXP(2.533 - .063 * (100. - sd(iihru)%cn2)))
                qn1 = Max(qn1, .4 * sd(iihru)%cn2)
                qn3 = sd(iihru)%cn2 * EXP(.00673 * (100. - sd(iihru)%cn2))
                sd(iihru)%smx = 254. * (100. / qn1 - 1.) 
                s3 = 254. * (100. / qn3 - 1.)
                rto3 = 1. - s3 / sd(iihru)%smx
                rtos = 1. - 2.54 / sd(iihru)%smx
                sumul = sd(iihru)%por
                sumfc = sd(iihru)%awc + sd(iihru)%cn3_swf * (sumul - sd(iihru)%awc)
                sumfc = Max (sumfc, .5 * sd(iihru)%awc)
                !! calculate shape parameters
                call ascrv(rto3, rtos, sumfc, sumul, sd(iihru)%wrt1, sd(iihru)%wrt2)
                sd_init(iihru) = sd(iihru)
              !end if
            end do
            lscalt(ireg)%lum(ilum)%nbyr = 0
            lscalt(ireg)%lum(ilum)%precip_aa = 0.
            lscalt(ireg)%lum(ilum)%aa = lscal_z
            end if
          end do
        end do
        ! cn3_swf adjustment
        if (isim > 0) then
          write (4304,*) " cn3_swf adj "
          call time_control
        end if
        end do      ! icn
          
      end do    ! iter_all loop
        
	  return
      end subroutine calt_hyd