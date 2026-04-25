<template>
    <div class="discover-page">
        <h2 class="section-title">{{ $t('fa-xian') }}</h2>

        <div class="discover-switch">
            <button v-for="tab in discoverTabs" :key="tab.key" class="switch-item"
                :class="{ active: activeDiscoverTab === tab.key }" @click="handleDiscoverTabClick(tab)">
                {{ tab.label }}
            </button>
        </div>

        <div v-if="activeDiscoverTab === 'playlist'" class="category-container">
            <div class="main-categories">
                <button v-for="(category, index) in categories" :key="index" @click="selectMainCategory(index)"
                    :class="{ active: selectedMainCategory === index }">
                    {{ category.tag_name }}
                </button>
            </div>

            <div class="sub-categories">
                <button v-for="(tab, index) in currentSubCategories" :key="index" @click="selectSubCategory(index)"
                    :class="{ active: selectedSubCategory === index }">
                    {{ tab.tag_name }}
                </button>
            </div>
        </div>

        <div v-else-if="activeDiscoverTab === 'newAlbum'" class="category-container">
            <div class="sub-categories album-categories">
                <button v-for="type in newAlbumTypes" :key="type.value || 'recommend'" @click="selectAlbumType(type.value)"
                    :class="{ active: selectedAlbumType === type.value }">
                    {{ type.label }}
                </button>
            </div>
        </div>

        <RankingContent v-if="activeDiscoverTab === 'ranking'" :player-control="props.playerControl" />

        <template v-else-if="isCardView">
            <CommonSkeleton v-if="isLoading" variant="card-grid" :count="10" />

            <div v-else class="music-grid">
                <div class="music-card" v-for="card in cardItems" :key="card.key">
                    <router-link :to="card.to">
                        <img :src="$getCover(card.cover, 240)" class="music-image" />
                        <div class="music-info">
                            <h3>{{ card.title }}</h3>
                            <p>{{ card.description }}</p>
                        </div>
                    </router-link>
                </div>
            </div>
        </template>

        <template v-else-if="activeDiscoverTab === 'newSong'">
            <CommonSkeleton v-if="isLoading" variant="song-list" :count="10" />

            <div v-else-if="newSongList.length > 0" class="song-section">
                <SongSearchList :songs="newSongList" @song-click="handleSongClick"
                    @song-contextmenu="showContextMenu" />

                <div v-if="showSongPagination" class="pagination">
                    <button @click="prevSongPage" :disabled="currentSongPage === 1">{{ $t('shang-yi-ye') }}</button>
                    <div class="page-numbers">
                        <button v-for="pageNum in displayedSongPageNumbers" :key="pageNum" :class="['page-number', {
                            active: pageNum === currentSongPage,
                            ellipsis: pageNum === '...'
                        }]" @click="pageNum !== '...' && goToSongPage(pageNum)" :disabled="pageNum === '...'">
                            {{ pageNum }}
                        </button>
                    </div>
                    <button @click="nextSongPage" :disabled="currentSongPage === totalSongPages">{{ $t('xia-yi-ye') }}</button>
                </div>
            </div>

            <div v-else class="discover-placeholder">
                <div class="placeholder-card">
                    <h3>新歌速递</h3>
                    <p>暂无数据</p>
                </div>
            </div>
        </template>

        <div v-else class="discover-placeholder">
            <div class="placeholder-card">
                <h3>{{ currentDiscoverTabLabel }}</h3>
                <p>功能后续添加</p>
            </div>
        </div>
    </div>

    <ContextMenu ref="contextMenuRef" :playerControl="props.playerControl" />
</template>

<script setup>
import { computed, ref, watch } from "vue";
import { useRoute, useRouter } from 'vue-router';
import ContextMenu from '../components/ContextMenu.vue';
import CommonSkeleton from '../components/CommonSkeleton.vue';
import RankingContent from '../components/RankingContent.vue';
import SongSearchList from '../components/search/SongSearchList.vue';
import { get } from '../utils/request';

const route = useRoute();
const router = useRouter();

const props = defineProps({
    playerControl: Object
});

const discoverTabs = [
    { key: 'playlist', label: '歌单' },
    { key: 'ranking', label: '排行榜' },
    { key: 'newAlbum', label: '新碟上架' },
    { key: 'newSong', label: '新歌速递' }
];

const newAlbumTypes = [
    { label: '推荐', value: '' },
    { label: '华语', value: '1' },
    { label: '欧美', value: '2' },
    { label: '日本', value: '3' },
    { label: '韩国', value: '4' }
];

const albumTypeMap = {
    1: 'chn',
    2: 'eur',
    3: 'jpn',
    4: 'kor'
};

const songPageSize = 20;
const categories = ref([]);
const selectedMainCategory = ref(0);
const selectedSubCategory = ref(0);
const tagId = ref(0);
const playlistList = ref([]);
const albumList = ref([]);
const newSongList = ref([]);
const isLoading = ref(true);
const activeDiscoverTab = ref('playlist');
const selectedAlbumType = ref('');
const currentSongPage = ref(1);
const totalSongPages = ref(1);
const contextMenuRef = ref(null);

const currentSubCategories = computed(() => {
    return categories.value[selectedMainCategory.value]?.son || [];
});

const currentDiscoverTabLabel = computed(() => {
    return discoverTabs.find(tab => tab.key === activeDiscoverTab.value)?.label || '歌单';
});

const isCardView = computed(() => {
    return activeDiscoverTab.value === 'playlist' || activeDiscoverTab.value === 'newAlbum';
});

const cardItems = computed(() => {
    if (activeDiscoverTab.value === 'newAlbum') {
        return albumList.value.map(album => ({
            key: `album-${album.albumid}`,
            to: {
                path: '/PlaylistDetail',
                query: { albumid: album.albumid }
            },
            cover: album.imgurl,
            title: album.albumname,
            description: [album.singername, album.publishtime?.split(' ')[0], album.songcount ? `${album.songcount}首` : '']
                .filter(Boolean)
                .join(' · ')
        }));
    }

    return playlistList.value.map(playlist => ({
        key: `playlist-${playlist.global_collection_id}`,
        to: {
            path: '/PlaylistDetail',
            query: { global_collection_id: playlist.global_collection_id }
        },
        cover: playlist.flexible_cover,
        title: playlist.specialname,
        description: playlist.intro
    }));
});

const showSongPagination = computed(() => {
    return totalSongPages.value > 1;
});

const displayedSongPageNumbers = computed(() => {
    return buildPageNumbers(totalSongPages.value, currentSongPage.value);
});

const normalizeDiscoverTab = (view) => {
    return discoverTabs.some(tab => tab.key === view) ? view : 'playlist';
};

const normalizeAlbumType = (type) => {
    const normalizedType = type == null ? '' : String(type);
    return newAlbumTypes.some(option => option.value === normalizedType) ? normalizedType : '';
};

const normalizePage = (page) => {
    const value = parseInt(page, 10);
    return Number.isNaN(value) || value < 1 ? 1 : value;
};

const buildPageNumbers = (total, current) => {
    const delta = 2;
    const pages = [];

    if (total <= 7) {
        for (let i = 1; i <= total; i++) {
            pages.push(i);
        }
        return pages;
    }

    pages.push(1);

    const leftBound = Math.max(2, current - delta);
    const rightBound = Math.min(total - 1, current + delta);

    if (leftBound > 2) {
        pages.push('...');
    }

    for (let i = leftBound; i <= rightBound; i++) {
        pages.push(i);
    }

    if (rightBound < total - 1) {
        pages.push('...');
    }

    pages.push(total);
    return pages;
};

const getAuthorNames = (authors = []) => {
    if (!Array.isArray(authors)) return '';
    return authors.map(item => item.author_name).filter(Boolean).join(' / ');
};

const mapNewSongToSearchSong = (song) => {
    const image = song.album_sizable_cover || song.trans_param?.union_cover || song.authors?.[0]?.sizable_avatar || './assets/images/ico.png';
    const singerName = song.author_name || getAuthorNames(song.authors) || '未知歌手';
    const displayName = song.filename || `${singerName} - ${song.songname || ''}`;

    return {
        Image: image,
        OriSongName: displayName,
        SongName: song.songname || '',
        SingerName: singerName,
        Duration: song.timelength || 0,
        PublishDate: song.publish_date || '',
        PublishTime: song.publish_date || '',
        FileHash: song.hash,
        HQFileHash: song.hash_high || song.hash_320 || song.hash,
        SQFileHash: song.hash_flac || song.hash_high || song.hash_320 || song.hash,
        FileName: displayName,
        MVHash: song.video_hash || '',
        AlbumID: song.album_id,
        AlbumName: song.album_name || '',
        IsOriginal: 0
    };
};

const getAlbumListFromResponse = (data, type) => {
    if (!type) {
        return ['chn', 'eur', 'jpn', 'kor'].flatMap(key => Array.isArray(data?.[key]) ? data[key] : []);
    }

    return data?.[albumTypeMap[type]] || [];
};

const updateDiscoverQuery = (view, options = {}) => {
    const nextQuery = { ...route.query };

    if (view === 'playlist') {
        delete nextQuery.view;
    } else {
        nextQuery.view = view;
    }

    if (view === 'newAlbum' && options.albumType) {
        nextQuery.albumType = options.albumType;
    } else {
        delete nextQuery.albumType;
    }

    if (view === 'newSong' && options.songPage > 1) {
        nextQuery.songPage = options.songPage;
    } else {
        delete nextQuery.songPage;
    }

    router.replace({
        path: '/discover',
        query: nextQuery
    });
};

const playSong = (hash, name, img, author) => {
    props.playerControl?.addSongToQueue(hash, name, img, author);
};

const showContextMenu = (event, song) => {
    if (!contextMenuRef.value) return;

    song.cover = song.Image?.replace("{size}", 480) || './assets/images/ico.png';
    song.timeLength = song.Duration;
    song.OriSongName = song.FileName || song.OriSongName || song.SongName;
    contextMenuRef.value.openContextMenu(event, song);
};

const handleSongClick = (song) => {
    playSong(
        song?.HQFileHash || song?.SQFileHash || song?.FileHash,
        song?.OriSongName,
        song?.Image?.replace('{size}', 480) || './assets/images/ico.png',
        song?.SingerName
    );
};

const fetchPlaylistTags = async () => {
    const response = await get('/playlist/tags');
    if (response.status !== 1) return;

    categories.value = response.data;
    if (categories.value.length === 0) return;

    const { main, sub } = route.query;
    if (main != null && sub != null) {
        selectedMainCategory.value = parseInt(main, 10);
        selectedSubCategory.value = parseInt(sub, 10);
        tagId.value = categories.value[selectedMainCategory.value]?.son?.[selectedSubCategory.value]?.tag_id || categories.value[0].son[0].tag_id;
    } else {
        tagId.value = categories.value[0].son[0].tag_id;
    }
};

const fetchPlaylistList = async () => {
    const response = await get(`/top/playlist?withsong=0&category_id=${tagId.value}`);
    if (response.status === 1) {
        playlistList.value = response.data.special_list;
    }
    isLoading.value = false;
};

const ensurePlaylistData = async () => {
    if (categories.value.length === 0) {
        await fetchPlaylistTags();
    }
    await fetchPlaylistList();
};

const fetchNewAlbums = async () => {
    isLoading.value = true;
    albumList.value = [];

    try {
        const response = await get('/top/album');
        if (response.status === 1) {
            albumList.value = getAlbumListFromResponse(response.data, selectedAlbumType.value);
        }
    } catch (error) {
        console.error('获取新碟上架失败:', error);
    } finally {
        isLoading.value = false;
    }
};

const fetchNewSongs = async () => {
    isLoading.value = true;
    newSongList.value = [];

    try {
        const response = await get('/top/song', {
            page: currentSongPage.value,
            pagesize: songPageSize
        });

        if (response.status === 1) {
            newSongList.value = Array.isArray(response.data) ? response.data.map(mapNewSongToSearchSong) : [];
            totalSongPages.value = Math.max(1, Math.ceil((response.total || 0) / songPageSize));
        }
    } catch (error) {
        console.error('获取新歌速递失败:', error);
    } finally {
        isLoading.value = false;
    }
};

const handleDiscoverTabClick = (tab) => {
    updateDiscoverQuery(tab.key, {
        albumType: tab.key === 'newAlbum' ? selectedAlbumType.value : '',
        songPage: tab.key === 'newSong' ? currentSongPage.value : 1
    });
};

const selectMainCategory = (index) => {
    if (!currentSubCategories.value.length) return;

    isLoading.value = true;
    playlistList.value = [];
    selectedMainCategory.value = index;
    selectedSubCategory.value = 0;
    tagId.value = currentSubCategories.value[0].tag_id;

    router.replace({
        path: '/discover',
        query: {
            main: index,
            sub: 0,
            tag: currentSubCategories.value[0].tag_id
        }
    });

    fetchPlaylistList();
};

const selectSubCategory = (index) => {
    isLoading.value = true;
    playlistList.value = [];
    selectedSubCategory.value = index;
    tagId.value = currentSubCategories.value[index].tag_id;

    router.replace({
        path: '/discover',
        query: {
            main: selectedMainCategory.value,
            sub: index,
            tag: currentSubCategories.value[index].tag_id
        }
    });

    fetchPlaylistList();
};

const selectAlbumType = (type) => {
    if (selectedAlbumType.value === type) return;
    selectedAlbumType.value = type;
    updateDiscoverQuery('newAlbum', { albumType: type });
};

const goToSongPage = (page) => {
    const nextPage = normalizePage(page);
    if (nextPage === currentSongPage.value) return;
    currentSongPage.value = nextPage;
    updateDiscoverQuery('newSong', { songPage: nextPage });
};

const nextSongPage = () => {
    if (currentSongPage.value < totalSongPages.value) {
        goToSongPage(currentSongPage.value + 1);
    }
};

const prevSongPage = () => {
    if (currentSongPage.value > 1) {
        goToSongPage(currentSongPage.value - 1);
    }
};

watch(() => [route.query.view, route.query.albumType, route.query.songPage], async ([view, albumType, songPage]) => {
    activeDiscoverTab.value = normalizeDiscoverTab(view);
    selectedAlbumType.value = normalizeAlbumType(albumType);
    currentSongPage.value = normalizePage(songPage);

    if (activeDiscoverTab.value === 'ranking') {
        isLoading.value = false;
        return;
    }

    if (activeDiscoverTab.value === 'playlist') {
        isLoading.value = true;
        await ensurePlaylistData();
        return;
    }

    if (activeDiscoverTab.value === 'newAlbum') {
        await fetchNewAlbums();
        return;
    }

    if (activeDiscoverTab.value === 'newSong') {
        await fetchNewSongs();
        return;
    }

    isLoading.value = false;
}, { immediate: true });
</script>

<style lang="scss" scoped>
.discover-page {
    padding: 20px;
}

.section-title {
    font-size: 28px;
    font-weight: bold;
    margin-bottom: 30px;
    color: var(--primary-color);
}

.category-container {
    margin-bottom: 30px;
}

.discover-switch {
    display: flex;
    gap: 6px;
    padding: 5px;
    margin-bottom: 24px;
    background: #f3f4f7;
    border: 1px solid #e8eaf0;
    border-radius: 14px;
}

.switch-item {
    flex: 1;
    min-width: 0;
    border: none;
    border-radius: 10px;
    background: transparent;
    color: #8b8f9c;
    font-size: 14px;
    font-weight: 600;
    line-height: 40px;
    cursor: pointer;
    transition: all 0.2s ease;

    &.active {
        background: #fff;
        color: var(--primary-color);
        box-shadow: 0 4px 12px rgba(15, 23, 42, 0.08);
    }
}

.main-categories {
    display: flex;
    gap: 10px;
    margin-bottom: 15px;

    button {
        background-color: var(--secondary-color);
        color: #fff;
        border: none;
        padding: 10px 20px;
        border-radius: 20px;
        cursor: pointer;
        font-size: 15px;

        &.active {
            background-color: var(--primary-color);
        }
    }
}

.sub-categories {
    display: flex;
    gap: 10px;
    flex-wrap: wrap;
    margin-bottom: 20px;

    button {
        background-color: #f5f5f5;
        border: none;
        padding: 8px 15px;
        border-radius: 15px;
        cursor: pointer;
        font-size: 14px;

        &.active {
            background-color: var(--secondary-color);
            color: #fff;
        }
    }
}

.album-categories {
    margin-bottom: 0;
}

.music-grid {
    display: flex;
    gap: 15px;
    flex-wrap: wrap;
    justify-content: space-evenly;
}

.music-card {
    background-color: #fff;
    border-radius: 10px;
    box-shadow: 0 4px 8px rgba(0, 0, 0, 0.1);
    transition: transform 0.3s ease, box-shadow 0.3s ease;
    padding: 10px;
    text-align: center;
    width: 180px;

    &:hover {
        transform: translateY(-5px);
        box-shadow: 0 10px 20px var(--color-box-shadow);
    }

    a {
        display: block;
        color: inherit;
        text-decoration: none;
    }

    img {
        width: 100%;
        border-radius: 8px;
    }
}

.music-info {
    h3 {
        font-size: 16px;
        margin: 10px 0 5px;
    }

    p {
        font-size: 12px;
        color: #666;
        display: -webkit-box;
        -webkit-line-clamp: 2;
        -webkit-box-orient: vertical;
        overflow: hidden;
        text-overflow: ellipsis;
        max-height: 50px;
        line-height: 25px;
    }
}

.song-section {
    display: grid;
    gap: 20px;
}

.pagination {
    display: flex;
    justify-content: center;
    align-items: center;
    margin: 20px 0;
    gap: 10px;
}

.page-numbers {
    display: flex;
    gap: 5px;
}

.page-number {
    padding: 8px 12px;
    background-color: #f5f5f5;
    border: 1px solid #ddd;
    border-radius: 4px;
    cursor: pointer;
    color: #333;
    min-width: 40px;
    transition: all 0.3s;

    &:hover {
        background-color: var(--primary-color);
        color: white;
    }

    &.active {
        background-color: var(--primary-color);
        color: white;
        border-color: var(--primary-color);
    }

    &.ellipsis {
        background-color: transparent;
        border: none;
        cursor: default;
        pointer-events: none;
        padding: 8px 8px;
        min-width: 30px;

        &:hover {
            background-color: transparent;
            color: #333;
        }
    }
}

.pagination button {
    padding: 8px 15px;
    background-color: white;
    color: #333;
    border: 1px solid #ddd;
    border-radius: 8px;
    cursor: pointer;
    transition: all 0.3s;

    &:hover:not(:disabled) {
        background-color: var(--primary-color);
        color: white;
    }

    &:disabled {
        background-color: white;
        color: #999;
        cursor: not-allowed;
        border-color: #ddd;
    }
}

.discover-placeholder {
    display: flex;
    justify-content: center;
    padding-top: 80px;
}

.placeholder-card {
    min-width: 260px;
    padding: 40px 48px;
    text-align: center;
    background: #fff;
    border-radius: 18px;
    box-shadow: 0 8px 24px rgba(15, 23, 42, 0.08);

    h3 {
        margin: 0 0 12px;
        font-size: 22px;
        color: var(--primary-color);
    }

    p {
        margin: 0;
        color: #8b8f9c;
        font-size: 14px;
    }
}

@media (max-width: 768px) {
    .discover-switch {
        gap: 4px;
        padding: 4px;
    }

    .switch-item {
        font-size: 12px;
        line-height: 36px;
    }

    .pagination {
        gap: 6px;
        flex-wrap: wrap;
    }

    .page-number {
        min-width: 36px;
        padding: 6px 10px;
    }
}
</style>
