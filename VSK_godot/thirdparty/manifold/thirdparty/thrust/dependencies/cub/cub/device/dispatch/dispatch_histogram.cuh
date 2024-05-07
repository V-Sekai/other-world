
/******************************************************************************
 * Copyright (c) 2011, Duane Merrill.  All rights reserved.
 * Copyright (c) 2011-2018, NVIDIA CORPORATION.  All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *     * Neither the name of the NVIDIA CORPORATION nor the
 *       names of its contributors may be used to endorse or promote products
 *       derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL NVIDIA CORPORATION BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 ******************************************************************************/

/**
 * @file
 *   cub::DeviceHistogram provides device-wide parallel operations for constructing histogram(s)
 *   from a sequence of samples data residing within device-accessible memory.
 */

#pragma once

#include <cub/agent/agent_histogram.cuh>
#include <cub/config.cuh>
#include <cub/detail/cpp_compatibility.cuh>
#include <cub/grid/grid_queue.cuh>
#include <cub/thread/thread_search.cuh>
#include <cub/util_debug.cuh>
#include <cub/util_deprecated.cuh>
#include <cub/util_device.cuh>
#include <cub/util_math.cuh>
#include <cub/util_type.cuh>

#include <thrust/system/cuda/detail/core/triple_chevron_launch.h>

#include <cuda/std/limits>
#include <cuda/std/type_traits>

#include <cstdio>
#include <iterator>
#include <limits>

#include <nv/target>

CUB_NAMESPACE_BEGIN

/******************************************************************************
 * Histogram kernel entry points
 *****************************************************************************/

/**
 * Histogram initialization kernel entry point
 *
 * @tparam NUM_ACTIVE_CHANNELS
 *   Number of channels actively being histogrammed
 *
 * @tparam CounterT
 *   Integer type for counting sample occurrences per histogram bin
 *
 * @tparam OffsetT
 *   Signed integer type for global offsets
 *
 * @param num_output_bins_wrapper
 *   Number of output histogram bins per channel
 *
 * @param d_output_histograms_wrapper
 *   Histogram counter data having logical dimensions
 *   `CounterT[NUM_ACTIVE_CHANNELS][num_bins.array[CHANNEL]]`
 *
 * @param tile_queue
 *   Drain queue descriptor for dynamically mapping tile data onto thread blocks
 */
template <int NUM_ACTIVE_CHANNELS, typename CounterT, typename OffsetT>
__global__ void
DeviceHistogramInitKernel(ArrayWrapper<int, NUM_ACTIVE_CHANNELS> num_output_bins_wrapper,
                          ArrayWrapper<CounterT *, NUM_ACTIVE_CHANNELS> d_output_histograms_wrapper,
                          GridQueue<int> tile_queue)
{
  if ((threadIdx.x == 0) && (blockIdx.x == 0))
  {
    tile_queue.ResetDrain();
  }

  int output_bin = (blockIdx.x * blockDim.x) + threadIdx.x;

#pragma unroll
  for (int CHANNEL = 0; CHANNEL < NUM_ACTIVE_CHANNELS; ++CHANNEL)
  {
    if (output_bin < num_output_bins_wrapper.array[CHANNEL])
    {
      d_output_histograms_wrapper.array[CHANNEL][output_bin] = 0;
    }
  }
}

/**
 * Histogram privatized sweep kernel entry point (multi-block).
 * Computes privatized histograms, one per thread block.
 *
 *
 * @tparam AgentHistogramPolicyT
 *   Parameterized AgentHistogramPolicy tuning policy type
 *
 * @tparam PRIVATIZED_SMEM_BINS
 *   Maximum number of histogram bins per channel (e.g., up to 256)
 *
 * @tparam NUM_CHANNELS
 *   Number of channels interleaved in the input data (may be greater than the number of channels
 *   being actively histogrammed)
 *
 * @tparam NUM_ACTIVE_CHANNELS
 *   Number of channels actively being histogrammed
 *
 * @tparam SampleIteratorT
 *   The input iterator type. \iterator.
 *
 * @tparam CounterT
 *   Integer type for counting sample occurrences per histogram bin
 *
 * @tparam PrivatizedDecodeOpT
 *   The transform operator type for determining privatized counter indices from samples,
 *   one for each channel
 *
 * @tparam OutputDecodeOpT
 *   The transform operator type for determining output bin-ids from privatized counter indices,
 *   one for each channel
 *
 * @tparam OffsetT
 *   integer type for global offsets
 *
 * @param d_samples
 *   Input data to reduce
 *
 * @param num_output_bins_wrapper
 *   The number bins per final output histogram
 *
 * @param num_privatized_bins_wrapper
 *   The number bins per privatized histogram
 *
 * @param d_output_histograms_wrapper
 *   Reference to final output histograms
 *
 * @param d_privatized_histograms_wrapper
 *   Reference to privatized histograms
 *
 * @param output_decode_op_wrapper
 *   The transform operator for determining output bin-ids from privatized counter indices,
 *   one for each channel
 *
 * @param privatized_decode_op_wrapper
 *   The transform operator for determining privatized counter indices from samples,
 *   one for each channel
 *
 * @param num_row_pixels
 *   The number of multi-channel pixels per row in the region of interest
 *
 * @param num_rows
 *   The number of rows in the region of interest
 *
 * @param row_stride_samples
 *   The number of samples between starts of consecutive rows in the region of interest
 *
 * @param tiles_per_row
 *   Number of image tiles per row
 *
 * @param tile_queue
 *   Drain queue descriptor for dynamically mapping tile data onto thread blocks
 */
template <typename ChainedPolicyT,
          int PRIVATIZED_SMEM_BINS,
          int NUM_CHANNELS,
          int NUM_ACTIVE_CHANNELS,
          typename SampleIteratorT,
          typename CounterT,
          typename PrivatizedDecodeOpT,
          typename OutputDecodeOpT,
          typename OffsetT>
__launch_bounds__(int(ChainedPolicyT::ActivePolicy::AgentHistogramPolicyT::BLOCK_THREADS)) __global__
  void DeviceHistogramSweepKernel(
    SampleIteratorT d_samples,
    ArrayWrapper<int, NUM_ACTIVE_CHANNELS> num_output_bins_wrapper,
    ArrayWrapper<int, NUM_ACTIVE_CHANNELS> num_privatized_bins_wrapper,
    ArrayWrapper<CounterT *, NUM_ACTIVE_CHANNELS> d_output_histograms_wrapper,
    ArrayWrapper<CounterT *, NUM_ACTIVE_CHANNELS> d_privatized_histograms_wrapper,
    ArrayWrapper<OutputDecodeOpT, NUM_ACTIVE_CHANNELS> output_decode_op_wrapper,
    ArrayWrapper<PrivatizedDecodeOpT, NUM_ACTIVE_CHANNELS> privatized_decode_op_wrapper,
    OffsetT num_row_pixels,
    OffsetT num_rows,
    OffsetT row_stride_samples,
    int tiles_per_row,
    GridQueue<int> tile_queue)
{
  // Thread block type for compositing input tiles
  using AgentHistogramPolicyT = typename ChainedPolicyT::ActivePolicy::AgentHistogramPolicyT;
  using AgentHistogramT = AgentHistogram<AgentHistogramPolicyT,
                                         PRIVATIZED_SMEM_BINS,
                                         NUM_CHANNELS,
                                         NUM_ACTIVE_CHANNELS,
                                         SampleIteratorT,
                                         CounterT,
                                         PrivatizedDecodeOpT,
                                         OutputDecodeOpT,
                                         OffsetT>;

  // Shared memory for AgentHistogram
  __shared__ typename AgentHistogramT::TempStorage temp_storage;

  AgentHistogramT agent(temp_storage,
                        d_samples,
                        num_output_bins_wrapper.array,
                        num_privatized_bins_wrapper.array,
                        d_output_histograms_wrapper.array,
                        d_privatized_histograms_wrapper.array,
                        output_decode_op_wrapper.array,
                        privatized_decode_op_wrapper.array);

  // Initialize counters
  agent.InitBinCounters();

  // Consume input tiles
  agent.ConsumeTiles(num_row_pixels, num_rows, row_stride_samples, tiles_per_row, tile_queue);

  // Store output to global (if necessary)
  agent.StoreOutput();
}

namespace detail
{

template <typename SampleT, int NUM_ACTIVE_CHANNELS>
struct device_histogram_policy_hub
{
  template <int NOMINAL_ITEMS_PER_THREAD>
  struct TScale
  {
    enum
    {
      V_SCALE = (sizeof(SampleT) + sizeof(int) - 1) / sizeof(int),
      VALUE   = CUB_MAX((NOMINAL_ITEMS_PER_THREAD / NUM_ACTIVE_CHANNELS / V_SCALE), 1)
    };
  };

  /// SM35
  struct Policy350 : ChainedPolicy<350, Policy350, Policy350>
  {
    // TODO This might be worth it to separate usual histogram and the multi one
    using AgentHistogramPolicyT =
      AgentHistogramPolicy<128, TScale<8>::VALUE, BLOCK_LOAD_DIRECT, LOAD_LDG, true, BLEND, true>;
  };

  /// SM50
  struct Policy500 : ChainedPolicy<500, Policy500, Policy350>
  {
    // TODO This might be worth it to separate usual histogram and the multi one
    using AgentHistogramPolicyT =
      AgentHistogramPolicy<384, TScale<16>::VALUE, BLOCK_LOAD_DIRECT, LOAD_LDG, true, SMEM, false>;
  };

  using MaxPolicy = Policy500;
};

template <int NUM_CHANNELS,
          int NUM_ACTIVE_CHANNELS,
          int PRIVATIZED_SMEM_BINS,
          typename SampleIteratorT,
          typename CounterT,
          typename PrivatizedDecodeOpT,
          typename OutputDecodeOpT,
          typename OffsetT,
          typename MaxPolicyT>
struct dispatch_histogram
{
  void *d_temp_storage;
  size_t &temp_storage_bytes;
  SampleIteratorT d_samples;
  CounterT **d_output_histograms;
  int *num_privatized_levels;
  PrivatizedDecodeOpT *privatized_decode_op;
  int *num_output_levels;
  OutputDecodeOpT *output_decode_op;
  int max_num_output_bins;
  OffsetT num_row_pixels;
  OffsetT num_rows;
  OffsetT row_stride_samples;
  cudaStream_t stream;

  CUB_RUNTIME_FUNCTION
  dispatch_histogram(void *d_temp_storage,
                     size_t &temp_storage_bytes,
                     SampleIteratorT d_samples,
                     CounterT *d_output_histograms[NUM_ACTIVE_CHANNELS],
                     int num_privatized_levels[NUM_ACTIVE_CHANNELS],
                     PrivatizedDecodeOpT privatized_decode_op[NUM_ACTIVE_CHANNELS],
                     int num_output_levels[NUM_ACTIVE_CHANNELS],
                     OutputDecodeOpT output_decode_op[NUM_ACTIVE_CHANNELS],
                     int max_num_output_bins,
                     OffsetT num_row_pixels,
                     OffsetT num_rows,
                     OffsetT row_stride_samples,
                     cudaStream_t stream)
      : d_temp_storage(d_temp_storage)
      , temp_storage_bytes(temp_storage_bytes)
      , d_samples(d_samples)
      , d_output_histograms(d_output_histograms)
      , num_privatized_levels(num_privatized_levels)
      , privatized_decode_op(privatized_decode_op)
      , num_output_levels(num_output_levels)
      , output_decode_op(output_decode_op)
      , max_num_output_bins(max_num_output_bins)
      , num_row_pixels(num_row_pixels)
      , num_rows(num_rows)
      , row_stride_samples(row_stride_samples)
      , stream(stream)
  {}

  template <typename ActivePolicyT,
            typename DeviceHistogramInitKernelT,
            typename DeviceHistogramSweepKernelT>
  CUB_RUNTIME_FUNCTION __forceinline__ cudaError_t
  Invoke(DeviceHistogramInitKernelT histogram_init_kernel,
         DeviceHistogramSweepKernelT histogram_sweep_kernel)
  {
    cudaError error = cudaSuccess;

    const int block_threads = ActivePolicyT::AgentHistogramPolicyT::BLOCK_THREADS;
    const int pixels_per_thread = ActivePolicyT::AgentHistogramPolicyT::PIXELS_PER_THREAD;

    do
    {
      // Get device ordinal
      int device_ordinal;
      if (CubDebug(error = cudaGetDevice(&device_ordinal)))
      {
        break;
      }

      // Get SM count
      int sm_count;
      if (CubDebug(error = cudaDeviceGetAttribute(&sm_count,
                                                  cudaDevAttrMultiProcessorCount,
                                                  device_ordinal)))
      {
        break;
      }

      // Get SM occupancy for histogram_sweep_kernel
      int histogram_sweep_sm_occupancy;
      if (CubDebug(error = MaxSmOccupancy(histogram_sweep_sm_occupancy,
                                          histogram_sweep_kernel,
                                          block_threads)))
      {
        break;
      }

      // Get device occupancy for histogram_sweep_kernel
      int histogram_sweep_occupancy = histogram_sweep_sm_occupancy * sm_count;

      if (num_row_pixels * NUM_CHANNELS == row_stride_samples)
      {
        // Treat as a single linear array of samples
        num_row_pixels *= num_rows;
        num_rows           = 1;
        row_stride_samples = num_row_pixels * NUM_CHANNELS;
      }

      // Get grid dimensions, trying to keep total blocks ~histogram_sweep_occupancy
      int pixels_per_tile = block_threads * pixels_per_thread;
      int tiles_per_row  = static_cast<int>(cub::DivideAndRoundUp(num_row_pixels, pixels_per_tile));
      int blocks_per_row = CUB_MIN(histogram_sweep_occupancy, tiles_per_row);
      int blocks_per_col = (blocks_per_row > 0)
                             ? int(CUB_MIN(histogram_sweep_occupancy / blocks_per_row, num_rows))
                             : 0;
      int num_thread_blocks = blocks_per_row * blocks_per_col;

      dim3 sweep_grid_dims;
      sweep_grid_dims.x = (unsigned int)blocks_per_row;
      sweep_grid_dims.y = (unsigned int)blocks_per_col;
      sweep_grid_dims.z = 1;

      // Temporary storage allocation requirements
      const int NUM_ALLOCATIONS          = NUM_ACTIVE_CHANNELS + 1;
      void *allocations[NUM_ALLOCATIONS] = {};
      size_t allocation_sizes[NUM_ALLOCATIONS];

      for (int CHANNEL = 0; CHANNEL < NUM_ACTIVE_CHANNELS; ++CHANNEL)
      {
        allocation_sizes[CHANNEL] = size_t(num_thread_blocks) *
                                    (num_privatized_levels[CHANNEL] - 1) * sizeof(CounterT);
      }

      allocation_sizes[NUM_ALLOCATIONS - 1] = GridQueue<int>::AllocationSize();

      // Alias the temporary allocations from the single storage blob (or compute the
      // necessary size of the blob)
      if (CubDebug(
            error =
              AliasTemporaries(d_temp_storage, temp_storage_bytes, allocations, allocation_sizes)))
      {
        break;
      }

      if (d_temp_storage == nullptr)
      {
        // Return if the caller is simply requesting the size of the storage allocation
        break;
      }

      // Construct the grid queue descriptor
      GridQueue<int> tile_queue(allocations[NUM_ALLOCATIONS - 1]);

      // Setup array wrapper for histogram channel output (because we can't pass static arrays
      // as kernel parameters)
      ArrayWrapper<CounterT *, NUM_ACTIVE_CHANNELS> d_output_histograms_wrapper;
      for (int CHANNEL = 0; CHANNEL < NUM_ACTIVE_CHANNELS; ++CHANNEL)
      {
        d_output_histograms_wrapper.array[CHANNEL] = d_output_histograms[CHANNEL];
      }

      // Setup array wrapper for privatized per-block histogram channel output (because we
      // can't pass static arrays as kernel parameters)
      ArrayWrapper<CounterT *, NUM_ACTIVE_CHANNELS> d_privatized_histograms_wrapper;
      for (int CHANNEL = 0; CHANNEL < NUM_ACTIVE_CHANNELS; ++CHANNEL)
      {
        d_privatized_histograms_wrapper.array[CHANNEL] = (CounterT *)allocations[CHANNEL];
      }

      // Setup array wrapper for sweep bin transforms (because we can't pass static arrays as
      // kernel parameters)
      ArrayWrapper<PrivatizedDecodeOpT, NUM_ACTIVE_CHANNELS> privatized_decode_op_wrapper;
      for (int CHANNEL = 0; CHANNEL < NUM_ACTIVE_CHANNELS; ++CHANNEL)
      {
        privatized_decode_op_wrapper.array[CHANNEL] = privatized_decode_op[CHANNEL];
      }

      // Setup array wrapper for aggregation bin transforms (because we can't pass static
      // arrays as kernel parameters)
      ArrayWrapper<OutputDecodeOpT, NUM_ACTIVE_CHANNELS> output_decode_op_wrapper;
      for (int CHANNEL = 0; CHANNEL < NUM_ACTIVE_CHANNELS; ++CHANNEL)
      {
        output_decode_op_wrapper.array[CHANNEL] = output_decode_op[CHANNEL];
      }

      // Setup array wrapper for num privatized bins (because we can't pass static arrays as
      // kernel parameters)
      ArrayWrapper<int, NUM_ACTIVE_CHANNELS> num_privatized_bins_wrapper;
      for (int CHANNEL = 0; CHANNEL < NUM_ACTIVE_CHANNELS; ++CHANNEL)
      {
        num_privatized_bins_wrapper.array[CHANNEL] = num_privatized_levels[CHANNEL] - 1;
      }

      // Setup array wrapper for num output bins (because we can't pass static arrays as
      // kernel parameters)
      ArrayWrapper<int, NUM_ACTIVE_CHANNELS> num_output_bins_wrapper;
      for (int CHANNEL = 0; CHANNEL < NUM_ACTIVE_CHANNELS; ++CHANNEL)
      {
        num_output_bins_wrapper.array[CHANNEL] = num_output_levels[CHANNEL] - 1;
      }

      int histogram_init_block_threads = 256;

      int histogram_init_grid_dims = (max_num_output_bins + histogram_init_block_threads - 1) /
                                     histogram_init_block_threads;

// Log DeviceHistogramInitKernel configuration
#ifdef CUB_DETAIL_DEBUG_ENABLE_LOG
      _CubLog("Invoking DeviceHistogramInitKernel<<<%d, %d, 0, %lld>>>()\n",
              histogram_init_grid_dims,
              histogram_init_block_threads,
              (long long)stream);
#endif

      // Invoke histogram_init_kernel
      THRUST_NS_QUALIFIER::cuda_cub::launcher::triple_chevron(histogram_init_grid_dims,
                                                              histogram_init_block_threads,
                                                              0,
                                                              stream)
        .doit(histogram_init_kernel,
              num_output_bins_wrapper,
              d_output_histograms_wrapper,
              tile_queue);

      // Return if empty problem
      if ((blocks_per_row == 0) || (blocks_per_col == 0))
      {
        break;
      }

// Log histogram_sweep_kernel configuration
#ifdef CUB_DETAIL_DEBUG_ENABLE_LOG
      _CubLog("Invoking histogram_sweep_kernel<<<{%d, %d, %d}, %d, 0, %lld>>>(), %d pixels "
              "per thread, %d SM occupancy\n",
              sweep_grid_dims.x,
              sweep_grid_dims.y,
              sweep_grid_dims.z,
              block_threads,
              (long long)stream,
              pixels_per_thread,
              histogram_sweep_sm_occupancy);
#endif

      // Invoke histogram_sweep_kernel
      THRUST_NS_QUALIFIER::cuda_cub::launcher::triple_chevron(sweep_grid_dims,
                                                              block_threads,
                                                              0,
                                                              stream)
        .doit(histogram_sweep_kernel,
              d_samples,
              num_output_bins_wrapper,
              num_privatized_bins_wrapper,
              d_output_histograms_wrapper,
              d_privatized_histograms_wrapper,
              output_decode_op_wrapper,
              privatized_decode_op_wrapper,
              num_row_pixels,
              num_rows,
              row_stride_samples,
              tiles_per_row,
              tile_queue);

      // Check for failure to launch
      if (CubDebug(error = cudaPeekAtLastError()))
      {
        break;
      }

      // Sync the stream if specified to flush runtime errors
      error = detail::DebugSyncStream(stream);
      if (CubDebug(error))
      {
        break;
      }
    } while (0);

    return error;
  }

  template <typename ActivePolicyT>
  CUB_RUNTIME_FUNCTION __forceinline__ cudaError_t Invoke()
  {
    return Invoke<ActivePolicyT>(DeviceHistogramInitKernel<NUM_ACTIVE_CHANNELS, CounterT, OffsetT>,
                                 DeviceHistogramSweepKernel<MaxPolicyT,
                                                            PRIVATIZED_SMEM_BINS,
                                                            NUM_CHANNELS,
                                                            NUM_ACTIVE_CHANNELS,
                                                            SampleIteratorT,
                                                            CounterT,
                                                            PrivatizedDecodeOpT,
                                                            OutputDecodeOpT,
                                                            OffsetT>);
  }
};

} // namespace detail

/******************************************************************************
 * Dispatch
 ******************************************************************************/

/**
 * Utility class for dispatching the appropriately-tuned kernels for DeviceHistogram
 *
 * @tparam NUM_CHANNELS
 *   Number of channels interleaved in the input data (may be greater than the number of channels
 *   being actively histogrammed)
 *
 * @tparam NUM_ACTIVE_CHANNELS
 *   Number of channels actively being histogrammed
 *
 * @tparam SampleIteratorT
 *   Random-access input iterator type for reading input items \iterator
 *
 * @tparam CounterT
 *   Integer type for counting sample occurrences per histogram bin
 *
 * @tparam LevelT
 *   Type for specifying bin level boundaries
 *
 * @tparam OffsetT
 *   Signed integer type for global offsets
 *
 * @tparam SelectedPolicy 
 *   Implementation detail, do not specify directly, requirements on the 
 *   content of this type are subject to breaking change.
 */
template <int NUM_CHANNELS,
          int NUM_ACTIVE_CHANNELS,
          typename SampleIteratorT,
          typename CounterT,
          typename LevelT,
          typename OffsetT,
          typename SelectedPolicy =            //
          detail::device_histogram_policy_hub< //
            cub::detail::value_t<SampleIteratorT>,
            NUM_ACTIVE_CHANNELS>>
struct DispatchHistogram : SelectedPolicy
{
public:
  //---------------------------------------------------------------------
  // Types and constants
  //---------------------------------------------------------------------

  /// The sample value type of the input iterator
  using SampleT = cub::detail::value_t<SampleIteratorT>;

  enum
  {
    // Maximum number of bins per channel for which we will use a privatized smem strategy
    MAX_PRIVATIZED_SMEM_BINS = 256
  };

  //---------------------------------------------------------------------
  // Transform functors for converting samples to bin-ids
  //---------------------------------------------------------------------

  // Searches for bin given a list of bin-boundary levels
  template <typename LevelIteratorT>
  struct SearchTransform
  {
    LevelIteratorT d_levels; // Pointer to levels array
    int num_output_levels;   // Number of levels in array

    /**
     * @brief Initializer
     *
     * @param d_levels_ Pointer to levels array
     * @param num_output_levels_ Number of levels in array
     */
    __host__ __device__ __forceinline__ void Init(LevelIteratorT d_levels_, int num_output_levels_)
    {
      this->d_levels          = d_levels_;
      this->num_output_levels = num_output_levels_;
    }

    // Method for converting samples to bin-ids
    template <CacheLoadModifier LOAD_MODIFIER, typename _SampleT>
    __host__ __device__ __forceinline__ void BinSelect(_SampleT sample, int &bin, bool valid)
    {
      /// Level iterator wrapper type
      // Wrap the native input pointer with CacheModifiedInputIterator
      // or Directly use the supplied input iterator type
      using WrappedLevelIteratorT =
        cub::detail::conditional_t<std::is_pointer<LevelIteratorT>::value,
                                   CacheModifiedInputIterator<LOAD_MODIFIER, LevelT, OffsetT>,
                                   LevelIteratorT>;

      WrappedLevelIteratorT wrapped_levels(d_levels);

      int num_bins = num_output_levels - 1;
      if (valid)
      {
        bin = UpperBound(wrapped_levels, num_output_levels, (LevelT)sample) - 1;
        if (bin >= num_bins)
          bin = -1;
      }
    }
  };

  // Scales samples to evenly-spaced bins
  struct ScaleTransform
  {
  private:
    using CommonT = typename ::cuda::std::common_type<LevelT, SampleT>::type;
    static_assert(::cuda::std::is_convertible<CommonT, int>::value,
                  "The common type of `LevelT` and `SampleT` must be "
                  "convertible to `int`.");
    static_assert(::cuda::std::is_trivially_copyable<CommonT>::value,
                  "The common type of `LevelT` and `SampleT` must be "
                  "trivially copyable.");

    // An arithmetic type that's used for bin computation of integral types, guaranteed to not
    // overflow for (max_level - min_level) * scale.fraction.bins. Since we drop invalid samples
    // of less than min_level, (sample - min_level) is guaranteed to be non-negative. We use the
    // rule: 2^l * 2^r = 2^(l + r) to determine a sufficiently large type to hold the
    // multiplication result.
    // If CommonT used to be a 128-bit wide integral type already, we use CommonT's arithmetic
    using IntArithmeticT = cub::detail::conditional_t<       //
      sizeof(SampleT) + sizeof(CommonT) <= sizeof(uint32_t), //
      uint32_t,                                              //
#if CUB_IS_INT128_ENABLED
      cub::detail::conditional_t<                            //
        (::cuda::std::is_same<CommonT, __int128_t>::value || //
         ::cuda::std::is_same<CommonT, __uint128_t>::value), //
        CommonT,                                             //
        uint64_t>                                            //
#else
      uint64_t
#endif
      >;

    // Alias template that excludes __[u]int128 from the integral types
    template <typename T>
    using is_integral_excl_int128 =
#if CUB_IS_INT128_ENABLED
      cub::detail::conditional_t<
        ::cuda::std::is_same<T, __int128_t>::value && ::cuda::std::is_same<T, __uint128_t>::value,
        ::cuda::std::false_type,
        ::cuda::std::is_integral<T>>;
#else
      ::cuda::std::is_integral<T>;
#endif

    union ScaleT
    {
      // Used when CommonT is not floating-point to avoid intermediate
      // rounding errors (see NVIDIA/cub#489).
      struct FractionT
      {
        CommonT bins;
        CommonT range;
      } fraction;

      // Used when CommonT is floating-point as an optimization.
      CommonT reciprocal;
    };

    CommonT m_max;  // Max sample level (exclusive)
    CommonT m_min;  // Min sample level (inclusive)
    ScaleT m_scale; // Bin scaling

    template <typename T>
    __host__ __device__ __forceinline__ ScaleT
    ComputeScale(int num_levels, T max_level, T min_level, ::cuda::std::true_type /* is_fp */)
    {
      ScaleT result;
      result.reciprocal =
        static_cast<T>(static_cast<T>(num_levels - 1) / static_cast<T>(max_level - min_level));
      return result;
    }

    template <typename T>
    __host__ __device__ __forceinline__ ScaleT
    ComputeScale(int num_levels, T max_level, T min_level, ::cuda::std::false_type /* is_fp */)
    {
      ScaleT result;
      result.fraction.bins  = static_cast<T>(num_levels - 1);
      result.fraction.range = static_cast<T>(max_level - min_level);
      return result;
    }

    template <typename T>
    __host__ __device__ __forceinline__ ScaleT ComputeScale(int num_levels,
                                                            T max_level,
                                                            T min_level)
    {
      return this->ComputeScale(num_levels,
                                max_level,
                                min_level,
                                ::cuda::std::is_floating_point<T>{});
    }

#ifdef __CUDA_FP16_TYPES_EXIST__
    __host__ __device__ __forceinline__ ScaleT ComputeScale(int num_levels,
                                                            __half max_level,
                                                            __half min_level)
    {
      NV_IF_TARGET(
        NV_PROVIDES_SM_53,
        (return this->ComputeScale(num_levels, max_level, min_level, ::cuda::std::true_type{});),
        (return this->ComputeScale(num_levels,
                                   __half2float(max_level),
                                   __half2float(min_level),
                                   ::cuda::std::true_type{});));
    }
#endif

    // All types but __half:
    template <typename T>
    __host__ __device__ __forceinline__ int SampleIsValid(T sample, T max_level, T min_level)
    {
      return sample >= min_level && sample < max_level;
    }

#ifdef __CUDA_FP16_TYPES_EXIST__
    __host__ __device__ __forceinline__ int SampleIsValid(__half sample,
                                                          __half max_level,
                                                          __half min_level)
    {
      NV_IF_TARGET(NV_PROVIDES_SM_53,
                   (return sample >= min_level && sample < max_level;),
                   (return this->SampleIsValid(__half2float(sample),
                                               __half2float(max_level),
                                               __half2float(min_level));));
    }
#endif

    /**
     * @brief Bin computation for floating point (and extended floating point) types
     */
    template <typename T>
    __host__ __device__ __forceinline__ int
    ComputeBin(T sample, T min_level, ScaleT scale, ::cuda::std::true_type /* is_fp */)
    {
      return static_cast<int>((sample - min_level) * scale.reciprocal);
    }

    /**
     * @brief Bin computation for custom types and __[u]int128
     */
    template <typename T>
    __host__ __device__ __forceinline__ int
    ComputeBin(T sample, T min_level, ScaleT scale, ::cuda::std::false_type /* is_fp */)
    {
      return static_cast<int>(((sample - min_level) * scale.fraction.bins) / scale.fraction.range);
    }

    /**
     * @brief Bin computation for integral types of up to 64-bit types
     */
    template <typename T,
              typename ::cuda::std::enable_if<is_integral_excl_int128<T>::value, int>::type = 0>
    __host__ __device__ __forceinline__ int ComputeBin(T sample, T min_level, ScaleT scale)
    {
      return static_cast<int>((static_cast<IntArithmeticT>(sample - min_level) *
                               static_cast<IntArithmeticT>(scale.fraction.bins)) /
                              static_cast<IntArithmeticT>(scale.fraction.range));
    }

    template <typename T,
              typename ::cuda::std::enable_if<!is_integral_excl_int128<T>::value, int>::type = 0>
    __host__ __device__ __forceinline__ int ComputeBin(T sample, T min_level, ScaleT scale)
    {
      return this->ComputeBin(sample, min_level, scale, ::cuda::std::is_floating_point<T>{});
    }

#ifdef __CUDA_FP16_TYPES_EXIST__
    __host__ __device__ __forceinline__ int ComputeBin(__half sample,
                                                       __half min_level,
                                                       ScaleT scale)
    {
      NV_IF_TARGET(NV_PROVIDES_SM_53,
                   (return this->ComputeBin(sample, min_level, scale, ::cuda::std::true_type{});),
                   (return static_cast<int>((__half2float(sample) - __half2float(min_level)) *
                                            __half2float(scale.reciprocal));));
    }
#endif

    __host__ __device__ __forceinline__ bool MayOverflow(CommonT /* num_bins */,
                                                         ::cuda::std::false_type /* is_integral */)
    {
      return false;
    }

    /**
     * @brief Returns true if the bin computation for a given combination of range `(max_level -
     * min_level)` and number of bins may overflow.
     */
    __host__ __device__ __forceinline__ bool MayOverflow(CommonT num_bins,
                                                         ::cuda::std::true_type /* is_integral */)
    {
      return static_cast<IntArithmeticT>(m_max - m_min) >
             (::cuda::std::numeric_limits<IntArithmeticT>::max() /
              static_cast<IntArithmeticT>(num_bins));
    }

  public:
    /**
     * @brief Initializes the ScaleTransform for the given parameters
     * @return cudaErrorInvalidValue if the ScaleTransform for the given values may overflow,
     * cudaSuccess otherwise
     */
    __host__ __device__ __forceinline__ cudaError_t Init(int num_levels,
                                                         LevelT max_level,
                                                         LevelT min_level)
    {
      m_max = static_cast<CommonT>(max_level);
      m_min = static_cast<CommonT>(min_level);

      // Check whether accurate bin computation for an integral sample type may overflow
      if (MayOverflow(static_cast<CommonT>(num_levels - 1), ::cuda::std::is_integral<CommonT>{}))
      {
        return cudaErrorInvalidValue;
      }

      m_scale = this->ComputeScale(num_levels, m_max, m_min);
      return cudaSuccess;
    }

    // Method for converting samples to bin-ids
    template <CacheLoadModifier LOAD_MODIFIER>
    __host__ __device__ __forceinline__ void BinSelect(SampleT sample, int &bin, bool valid)
    {
      const CommonT common_sample = static_cast<CommonT>(sample);

      if (valid && this->SampleIsValid(common_sample, m_max, m_min))
      {
        bin = this->ComputeBin(common_sample, m_min, m_scale);
      }
    }
  };

  // Pass-through bin transform operator
  struct PassThruTransform
  {
    // Method for converting samples to bin-ids
    template <CacheLoadModifier LOAD_MODIFIER, typename _SampleT>
    __host__ __device__ __forceinline__ void BinSelect(_SampleT sample, int &bin, bool valid)
    {
      if (valid)
        bin = (int)sample;
    }
  };

  //---------------------------------------------------------------------
  // Dispatch entrypoints
  //---------------------------------------------------------------------

  /**
   * Dispatch routine for HistogramRange, specialized for sample types larger than 8bit
   *
   * @param d_temp_storage
   *   Device-accessible allocation of temporary storage.
   *   When NULL, the required allocation size is written to `temp_storage_bytes` and
   *   no work is done.
   *
   * @param temp_storage_bytes
   *   Reference to size in bytes of `d_temp_storage` allocation
   *
   * @param d_samples
   *   The pointer to the multi-channel input sequence of data samples.
   *   The samples from different channels are assumed to be interleaved
   *   (e.g., an array of 32-bit pixels where each pixel consists of four RGBA 8-bit samples).
   *
   * @param d_output_histograms
   *   The pointers to the histogram counter output arrays, one for each active channel.
   *   For channel<sub><em>i</em></sub>, the allocation length of `d_histograms[i]` should be
   *   `num_output_levels[i] - 1`.
   *
   * @param num_output_levels
   *   The number of boundaries (levels) for delineating histogram samples in each active channel.
   *   Implies that the number of bins for channel<sub><em>i</em></sub> is
   *   `num_output_levels[i] - 1`.
   *
   * @param d_levels
   *   The pointers to the arrays of boundaries (levels), one for each active channel.
   *   Bin ranges are defined by consecutive boundary pairings: lower sample value boundaries are
   *   inclusive and upper sample value boundaries are exclusive.
   *
   * @param num_row_pixels
   *   The number of multi-channel pixels per row in the region of interest
   *
   * @param num_rows
   *   The number of rows in the region of interest
   *
   * @param row_stride_samples
   *   The number of samples between starts of consecutive rows in the region of interest
   *
   * @param stream
   *   CUDA stream to launch kernels within. Default is stream<sub>0</sub>.
   *
   * @param is_byte_sample
   *   type indicating whether or not SampleT is a 8b type
   */
  CUB_RUNTIME_FUNCTION
  static cudaError_t DispatchRange(void *d_temp_storage,
                                   size_t &temp_storage_bytes,
                                   SampleIteratorT d_samples,
                                   CounterT *d_output_histograms[NUM_ACTIVE_CHANNELS],
                                   int num_output_levels[NUM_ACTIVE_CHANNELS],
                                   LevelT *d_levels[NUM_ACTIVE_CHANNELS],
                                   OffsetT num_row_pixels,
                                   OffsetT num_rows,
                                   OffsetT row_stride_samples,
                                   cudaStream_t stream,
                                   Int2Type<false> /*is_byte_sample*/)
  {
    using MaxPolicyT = typename SelectedPolicy::MaxPolicy;
    cudaError error  = cudaSuccess;

    do
    {
      // Get PTX version
      int ptx_version = 0;
      if (CubDebug(error = PtxVersion(ptx_version)))
      {
        break;
      }

      // Use the search transform op for converting samples to privatized bins
      typedef SearchTransform<LevelT *> PrivatizedDecodeOpT;

      // Use the pass-thru transform op for converting privatized bins to output bins
      typedef PassThruTransform OutputDecodeOpT;

      PrivatizedDecodeOpT privatized_decode_op[NUM_ACTIVE_CHANNELS];
      OutputDecodeOpT output_decode_op[NUM_ACTIVE_CHANNELS];
      int max_levels = num_output_levels[0];

      for (int channel = 0; channel < NUM_ACTIVE_CHANNELS; ++channel)
      {
        privatized_decode_op[channel].Init(d_levels[channel], num_output_levels[channel]);
        if (num_output_levels[channel] > max_levels)
        {
          max_levels = num_output_levels[channel];
        }
      }
      int max_num_output_bins = max_levels - 1;

      // Dispatch
      if (max_num_output_bins > MAX_PRIVATIZED_SMEM_BINS)
      {
        // Too many bins to keep in shared memory.
        const int PRIVATIZED_SMEM_BINS = 0;

        detail::dispatch_histogram<NUM_CHANNELS,
                                   NUM_ACTIVE_CHANNELS,
                                   PRIVATIZED_SMEM_BINS,
                                   SampleIteratorT,
                                   CounterT,
                                   PrivatizedDecodeOpT,
                                   OutputDecodeOpT,
                                   OffsetT,
                                   MaxPolicyT>
          dispatch(d_temp_storage,
                   temp_storage_bytes,
                   d_samples,
                   d_output_histograms,
                   num_output_levels,
                   privatized_decode_op,
                   num_output_levels,
                   output_decode_op,
                   max_num_output_bins,
                   num_row_pixels,
                   num_rows,
                   row_stride_samples,
                   stream);

        if (CubDebug(error = MaxPolicyT::Invoke(ptx_version, dispatch)))
        {
          break;
        }
      }
      else
      {
        // Dispatch shared-privatized approach
        const int PRIVATIZED_SMEM_BINS = MAX_PRIVATIZED_SMEM_BINS;

        detail::dispatch_histogram<NUM_CHANNELS,
                                   NUM_ACTIVE_CHANNELS,
                                   PRIVATIZED_SMEM_BINS,
                                   SampleIteratorT,
                                   CounterT,
                                   PrivatizedDecodeOpT,
                                   OutputDecodeOpT,
                                   OffsetT,
                                   MaxPolicyT>
          dispatch(d_temp_storage,
                   temp_storage_bytes,
                   d_samples,
                   d_output_histograms,
                   num_output_levels,
                   privatized_decode_op,
                   num_output_levels,
                   output_decode_op,
                   max_num_output_bins,
                   num_row_pixels,
                   num_rows,
                   row_stride_samples,
                   stream);

        if (CubDebug(error = MaxPolicyT::Invoke(ptx_version, dispatch)))
        {
          break;
        }
      }
    } while (0);

    return error;
  }

  CUB_DETAIL_RUNTIME_DEBUG_SYNC_IS_NOT_SUPPORTED
  CUB_RUNTIME_FUNCTION
  static cudaError_t DispatchRange(void *d_temp_storage,
                                   size_t &temp_storage_bytes,
                                   SampleIteratorT d_samples,
                                   CounterT *d_output_histograms[NUM_ACTIVE_CHANNELS],
                                   int num_output_levels[NUM_ACTIVE_CHANNELS],
                                   LevelT *d_levels[NUM_ACTIVE_CHANNELS],
                                   OffsetT num_row_pixels,
                                   OffsetT num_rows,
                                   OffsetT row_stride_samples,
                                   cudaStream_t stream,
                                   bool debug_synchronous,
                                   Int2Type<false> is_byte_sample)
  {
    CUB_DETAIL_RUNTIME_DEBUG_SYNC_USAGE_LOG

    return DispatchRange(d_temp_storage,
                         temp_storage_bytes,
                         d_samples,
                         d_output_histograms,
                         num_output_levels,
                         d_levels,
                         num_row_pixels,
                         num_rows,
                         row_stride_samples,
                         stream,
                         is_byte_sample);
  }

  /**
   * Dispatch routine for HistogramRange, specialized for 8-bit sample types
   * (computes 256-bin privatized histograms and then reduces to user-specified levels)
   *
   * @param d_temp_storage
   *   Device-accessible allocation of temporary storage.
   *   When NULL, the required allocation size is written to `temp_storage_bytes` and
   *   no work is done.
   *
   * @param temp_storage_bytes
   *   Reference to size in bytes of `d_temp_storage` allocation
   *
   * @param d_samples
   *   The pointer to the multi-channel input sequence of data samples.
   *   The samples from different channels are assumed to be interleaved
   *   (e.g., an array of 32-bit pixels where each pixel consists of four RGBA 8-bit samples).
   *
   * @param d_output_histograms
   *   The pointers to the histogram counter output arrays, one for each active channel.
   *   For channel<sub><em>i</em></sub>, the allocation length of
   *   `d_histograms[i]` should be `num_output_levels[i] - 1`.
   *
   * @param num_output_levels
   *   The number of boundaries (levels) for delineating histogram samples in each active channel.
   *   Implies that the number of bins for channel<sub><em>i</em></sub> is
   *   `num_output_levels[i] - 1`.
   *
   * @param d_levels
   *   The pointers to the arrays of boundaries (levels), one for each active channel.
   *   Bin ranges are defined by consecutive boundary pairings: lower sample value boundaries are
   *   inclusive and upper sample value boundaries are exclusive.
   *
   * @param num_row_pixels
   *   The number of multi-channel pixels per row in the region of interest
   *
   * @param num_rows
   *   The number of rows in the region of interest
   *
   * @param row_stride_samples
   *   The number of samples between starts of consecutive rows in the region of interest
   *
   * @param stream
   *   CUDA stream to launch kernels within.  Default is stream<sub>0</sub>.
   *
   * @param is_byte_sample
   *   Marker type indicating whether or not SampleT is a 8b type
   */
  CUB_RUNTIME_FUNCTION
  static cudaError_t DispatchRange(void *d_temp_storage,
                                   size_t &temp_storage_bytes,
                                   SampleIteratorT d_samples,
                                   CounterT *d_output_histograms[NUM_ACTIVE_CHANNELS],
                                   int num_output_levels[NUM_ACTIVE_CHANNELS],
                                   LevelT *d_levels[NUM_ACTIVE_CHANNELS],
                                   OffsetT num_row_pixels,
                                   OffsetT num_rows,
                                   OffsetT row_stride_samples,
                                   cudaStream_t stream,
                                   Int2Type<true> /*is_byte_sample*/)
  {
    using MaxPolicyT = typename SelectedPolicy::MaxPolicy;
    cudaError error = cudaSuccess;

    do
    {
      // Get PTX version
      int ptx_version = 0;
      if (CubDebug(error = PtxVersion(ptx_version)))
      {
        break;
      }

      // Use the pass-thru transform op for converting samples to privatized bins
      typedef PassThruTransform PrivatizedDecodeOpT;

      // Use the search transform op for converting privatized bins to output bins
      typedef SearchTransform<LevelT *> OutputDecodeOpT;

      int num_privatized_levels[NUM_ACTIVE_CHANNELS];
      PrivatizedDecodeOpT privatized_decode_op[NUM_ACTIVE_CHANNELS];
      OutputDecodeOpT output_decode_op[NUM_ACTIVE_CHANNELS];
      int max_levels = num_output_levels[0]; // Maximum number of levels in any channel

      for (int channel = 0; channel < NUM_ACTIVE_CHANNELS; ++channel)
      {
        num_privatized_levels[channel] = 257;
        output_decode_op[channel].Init(d_levels[channel], num_output_levels[channel]);

        if (num_output_levels[channel] > max_levels)
        {
          max_levels = num_output_levels[channel];
        }
      }
      int max_num_output_bins = max_levels - 1;

      const int PRIVATIZED_SMEM_BINS = 256;

      detail::dispatch_histogram<NUM_CHANNELS,
                                 NUM_ACTIVE_CHANNELS,
                                 PRIVATIZED_SMEM_BINS,
                                 SampleIteratorT,
                                 CounterT,
                                 PrivatizedDecodeOpT,
                                 OutputDecodeOpT,
                                 OffsetT,
                                 MaxPolicyT>
        dispatch(d_temp_storage,
                 temp_storage_bytes,
                 d_samples,
                 d_output_histograms,
                 num_privatized_levels,
                 privatized_decode_op,
                 num_output_levels,
                 output_decode_op,
                 max_num_output_bins,
                 num_row_pixels,
                 num_rows,
                 row_stride_samples,
                 stream);

      if (CubDebug(error = MaxPolicyT::Invoke(ptx_version, dispatch)))
      {
        break;
      }
    } while (0);

    return error;
  }

  CUB_DETAIL_RUNTIME_DEBUG_SYNC_IS_NOT_SUPPORTED
  CUB_RUNTIME_FUNCTION
  static cudaError_t DispatchRange(void *d_temp_storage,
                                   size_t &temp_storage_bytes,
                                   SampleIteratorT d_samples,
                                   CounterT *d_output_histograms[NUM_ACTIVE_CHANNELS],
                                   int num_output_levels[NUM_ACTIVE_CHANNELS],
                                   LevelT *d_levels[NUM_ACTIVE_CHANNELS],
                                   OffsetT num_row_pixels,
                                   OffsetT num_rows,
                                   OffsetT row_stride_samples,
                                   cudaStream_t stream,
                                   bool debug_synchronous,
                                   Int2Type<true> is_byte_sample)
  {
    CUB_DETAIL_RUNTIME_DEBUG_SYNC_USAGE_LOG

    return DispatchRange(d_temp_storage,
                         temp_storage_bytes,
                         d_samples,
                         d_output_histograms,
                         num_output_levels,
                         d_levels,
                         num_row_pixels,
                         num_rows,
                         row_stride_samples,
                         stream,
                         is_byte_sample);
  }

  /**
   * Dispatch routine for HistogramEven, specialized for sample types larger than 8-bit
   *
   * @param d_temp_storage
   *   Device-accessible allocation of temporary storage.
   *   When NULL, the required allocation size is written to
   *   `temp_storage_bytes` and no work is done.
   *
   * @param temp_storage_bytes
   *   Reference to size in bytes of `d_temp_storage` allocation
   *
   * @param d_samples
   *   The pointer to the input sequence of sample items.
   *   The samples from different channels are assumed to be interleaved
   *   (e.g., an array of 32-bit pixels where each pixel consists of four RGBA 8-bit samples).
   *
   * @param d_output_histograms
   *   The pointers to the histogram counter output arrays, one for each active channel.
   *   For channel<sub><em>i</em></sub>, the allocation length of `d_histograms[i]` should be
   *   `num_output_levels[i] - 1`.
   *
   * @param num_output_levels
   *   The number of bin level boundaries for delineating histogram samples in each active channel.
   *   Implies that the number of bins for channel<sub><em>i</em></sub> is
   *   `num_output_levels[i] - 1`.
   *
   * @param lower_level
   *   The lower sample value bound (inclusive) for the lowest histogram bin in each active channel.
   *
   * @param upper_level
   *   The upper sample value bound (exclusive) for the highest histogram bin in each active
   * channel.
   *
   * @param num_row_pixels
   *   The number of multi-channel pixels per row in the region of interest
   *
   * @param num_rows
   *   The number of rows in the region of interest
   *
   * @param row_stride_samples
   *   The number of samples between starts of consecutive rows in the region of interest
   *
   * @param stream
   *   CUDA stream to launch kernels within.  Default is stream<sub>0</sub>.
   *
   * @param is_byte_sample
   *   Marker type indicating whether or not SampleT is a 8b type
   */
  CUB_RUNTIME_FUNCTION __forceinline__ static cudaError_t
  DispatchEven(void *d_temp_storage,
               size_t &temp_storage_bytes,
               SampleIteratorT d_samples,
               CounterT *d_output_histograms[NUM_ACTIVE_CHANNELS],
               int num_output_levels[NUM_ACTIVE_CHANNELS],
               LevelT lower_level[NUM_ACTIVE_CHANNELS],
               LevelT upper_level[NUM_ACTIVE_CHANNELS],
               OffsetT num_row_pixels,
               OffsetT num_rows,
               OffsetT row_stride_samples,
               cudaStream_t stream,
               Int2Type<false> /*is_byte_sample*/)
  {
    using MaxPolicyT = typename SelectedPolicy::MaxPolicy;
    cudaError error = cudaSuccess;

    do
    {
      // Get PTX version
      int ptx_version = 0;
      if (CubDebug(error = PtxVersion(ptx_version)))
      {
        break;
      }

      // Use the scale transform op for converting samples to privatized bins
      typedef ScaleTransform PrivatizedDecodeOpT;

      // Use the pass-thru transform op for converting privatized bins to output bins
      typedef PassThruTransform OutputDecodeOpT;

      PrivatizedDecodeOpT privatized_decode_op[NUM_ACTIVE_CHANNELS];
      OutputDecodeOpT output_decode_op[NUM_ACTIVE_CHANNELS];
      int max_levels = num_output_levels[0];

      for (int channel = 0; channel < NUM_ACTIVE_CHANNELS; ++channel)
      {
        error = privatized_decode_op[channel].Init(num_output_levels[channel],
                                                   upper_level[channel],
                                                   lower_level[channel]);
        if (CubDebug(error != cudaSuccess))
        {
          // Make sure to also return a reasonable value for `temp_storage_bytes` in case of
          // an overflow of the bin computation, in which case a subsequent algorithm
          // invocation will also fail
          if (!d_temp_storage)
          {
            temp_storage_bytes = 1U;
          }
          return error;
        }

        if (num_output_levels[channel] > max_levels)
        {
          max_levels = num_output_levels[channel];
        }
      }
      int max_num_output_bins = max_levels - 1;

      if (max_num_output_bins > MAX_PRIVATIZED_SMEM_BINS)
      {
        // Dispatch shared-privatized approach
        const int PRIVATIZED_SMEM_BINS = 0;

        detail::dispatch_histogram<NUM_CHANNELS,
                                   NUM_ACTIVE_CHANNELS,
                                   PRIVATIZED_SMEM_BINS,
                                   SampleIteratorT,
                                   CounterT,
                                   PrivatizedDecodeOpT,
                                   OutputDecodeOpT,
                                   OffsetT,
                                   MaxPolicyT>
          dispatch(d_temp_storage,
                   temp_storage_bytes,
                   d_samples,
                   d_output_histograms,
                   num_output_levels,
                   privatized_decode_op,
                   num_output_levels,
                   output_decode_op,
                   max_num_output_bins,
                   num_row_pixels,
                   num_rows,
                   row_stride_samples,
                   stream);

        if (CubDebug(error = MaxPolicyT::Invoke(ptx_version, dispatch)))
        {
          break;
        }
      }
      else
      {
        // Dispatch shared-privatized approach
        const int PRIVATIZED_SMEM_BINS = MAX_PRIVATIZED_SMEM_BINS;

        detail::dispatch_histogram<NUM_CHANNELS,
                                   NUM_ACTIVE_CHANNELS,
                                   PRIVATIZED_SMEM_BINS,
                                   SampleIteratorT,
                                   CounterT,
                                   PrivatizedDecodeOpT,
                                   OutputDecodeOpT,
                                   OffsetT,
                                   MaxPolicyT>
          dispatch(d_temp_storage,
                   temp_storage_bytes,
                   d_samples,
                   d_output_histograms,
                   num_output_levels,
                   privatized_decode_op,
                   num_output_levels,
                   output_decode_op,
                   max_num_output_bins,
                   num_row_pixels,
                   num_rows,
                   row_stride_samples,
                   stream);

        if (CubDebug(error = MaxPolicyT::Invoke(ptx_version, dispatch)))
        {
          break;
        }
      }
    } while (0);

    return error;
  }

  CUB_DETAIL_RUNTIME_DEBUG_SYNC_IS_NOT_SUPPORTED
  CUB_RUNTIME_FUNCTION __forceinline__ static cudaError_t
  DispatchEven(void *d_temp_storage,
               size_t &temp_storage_bytes,
               SampleIteratorT d_samples,
               CounterT *d_output_histograms[NUM_ACTIVE_CHANNELS],
               int num_output_levels[NUM_ACTIVE_CHANNELS],
               LevelT lower_level[NUM_ACTIVE_CHANNELS],
               LevelT upper_level[NUM_ACTIVE_CHANNELS],
               OffsetT num_row_pixels,
               OffsetT num_rows,
               OffsetT row_stride_samples,
               cudaStream_t stream,
               bool debug_synchronous,
               Int2Type<false> is_byte_sample)
  {
    CUB_DETAIL_RUNTIME_DEBUG_SYNC_USAGE_LOG

    return DispatchEven(d_temp_storage,
                        temp_storage_bytes,
                        d_samples,
                        d_output_histograms,
                        num_output_levels,
                        lower_level,
                        upper_level,
                        num_row_pixels,
                        num_rows,
                        row_stride_samples,
                        stream,
                        is_byte_sample);
  }

  /**
   * Dispatch routine for HistogramEven, specialized for 8-bit sample types
   * (computes 256-bin privatized histograms and then reduces to user-specified levels)
   *
   * @param d_temp_storage
   *   Device-accessible allocation of temporary storage.
   *   When NULL, the required allocation size is written to `temp_storage_bytes` and
   *   no work is done.
   *
   * @param temp_storage_bytes
   *   Reference to size in bytes of `d_temp_storage` allocation
   *
   * @param d_samples
   *   The pointer to the input sequence of sample items. The samples from different channels are
   *   assumed to be interleaved (e.g., an array of 32-bit pixels where each pixel consists of
   *   four RGBA 8-bit samples).
   *
   * @param d_output_histograms
   *   The pointers to the histogram counter output arrays, one for each active channel.
   *   For channel<sub><em>i</em></sub>, the allocation length of `d_histograms[i]` should be
   *   `num_output_levels[i] - 1`.
   *
   * @param num_output_levels
   *   The number of bin level boundaries for delineating histogram samples in each active channel.
   *   Implies that the number of bins for channel<sub><em>i</em></sub> is
   *   `num_output_levels[i] - 1`.
   *
   * @param lower_level
   *   The lower sample value bound (inclusive) for the lowest histogram bin in each active channel.
   *
   * @param upper_level
   *   The upper sample value bound (exclusive) for the highest histogram bin in each active
   * channel.
   *
   * @param num_row_pixels
   *   The number of multi-channel pixels per row in the region of interest
   *
   * @param num_rows
   *   The number of rows in the region of interest
   *
   * @param row_stride_samples
   *   The number of samples between starts of consecutive rows in the region of interest
   *
   * @param stream
   *   CUDA stream to launch kernels within.  Default is stream<sub>0</sub>.
   *
   * @param is_byte_sample
   *   type indicating whether or not SampleT is a 8b type
   */
  CUB_RUNTIME_FUNCTION __forceinline__ static cudaError_t
  DispatchEven(void *d_temp_storage,
               size_t &temp_storage_bytes,
               SampleIteratorT d_samples,
               CounterT *d_output_histograms[NUM_ACTIVE_CHANNELS],
               int num_output_levels[NUM_ACTIVE_CHANNELS],
               LevelT lower_level[NUM_ACTIVE_CHANNELS],
               LevelT upper_level[NUM_ACTIVE_CHANNELS],
               OffsetT num_row_pixels,
               OffsetT num_rows,
               OffsetT row_stride_samples,
               cudaStream_t stream,
               Int2Type<true> /*is_byte_sample*/)
  {
    using MaxPolicyT = typename SelectedPolicy::MaxPolicy;
    cudaError error = cudaSuccess;

    do
    {
      // Get PTX version
      int ptx_version = 0;
      if (CubDebug(error = PtxVersion(ptx_version)))
      {
        break;
      }

      // Use the pass-thru transform op for converting samples to privatized bins
      typedef PassThruTransform PrivatizedDecodeOpT;

      // Use the scale transform op for converting privatized bins to output bins
      typedef ScaleTransform OutputDecodeOpT;

      int num_privatized_levels[NUM_ACTIVE_CHANNELS];
      PrivatizedDecodeOpT privatized_decode_op[NUM_ACTIVE_CHANNELS];
      OutputDecodeOpT output_decode_op[NUM_ACTIVE_CHANNELS];
      int max_levels = num_output_levels[0];

      for (int channel = 0; channel < NUM_ACTIVE_CHANNELS; ++channel)
      {
        num_privatized_levels[channel] = 257;

        output_decode_op[channel].Init(num_output_levels[channel],
                                       upper_level[channel],
                                       lower_level[channel]);

        if (num_output_levels[channel] > max_levels)
        {
          max_levels = num_output_levels[channel];
        }
      }
      int max_num_output_bins = max_levels - 1;

      const int PRIVATIZED_SMEM_BINS = 256;

      detail::dispatch_histogram<NUM_CHANNELS,
                                 NUM_ACTIVE_CHANNELS,
                                 PRIVATIZED_SMEM_BINS,
                                 SampleIteratorT,
                                 CounterT,
                                 PrivatizedDecodeOpT,
                                 OutputDecodeOpT,
                                 OffsetT,
                                 MaxPolicyT>
        dispatch(d_temp_storage,
                 temp_storage_bytes,
                 d_samples,
                 d_output_histograms,
                 num_privatized_levels,
                 privatized_decode_op,
                 num_output_levels,
                 output_decode_op,
                 max_num_output_bins,
                 num_row_pixels,
                 num_rows,
                 row_stride_samples,
                 stream);

      if (CubDebug(error = MaxPolicyT::Invoke(ptx_version, dispatch)))
      {
        break;
      }
    } while (0);

    return error;
  }

  CUB_RUNTIME_FUNCTION __forceinline__ static cudaError_t
  DispatchEven(void *d_temp_storage,
               size_t &temp_storage_bytes,
               SampleIteratorT d_samples,
               CounterT *d_output_histograms[NUM_ACTIVE_CHANNELS],
               int num_output_levels[NUM_ACTIVE_CHANNELS],
               LevelT lower_level[NUM_ACTIVE_CHANNELS],
               LevelT upper_level[NUM_ACTIVE_CHANNELS],
               OffsetT num_row_pixels,
               OffsetT num_rows,
               OffsetT row_stride_samples,
               cudaStream_t stream,
               bool debug_synchronous,
               Int2Type<true> is_byte_sample)
  {
    CUB_DETAIL_RUNTIME_DEBUG_SYNC_USAGE_LOG

    return DispatchEven(d_temp_storage,
                        temp_storage_bytes,
                        d_samples,
                        d_output_histograms,
                        num_output_levels,
                        lower_level,
                        upper_level,
                        num_row_pixels,
                        num_rows,
                        row_stride_samples,
                        stream,
                        is_byte_sample);
  }
};

CUB_NAMESPACE_END
